#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

###############################################################################
# 1) Import command (resilient ITU download + non-destructive multi-MNC merge)
###############################################################################
mkdir -p app/Console/Commands
cat > app/Console/Commands/ImportCarriers.php <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--fresh} {--source=itu}';
    protected $description = 'Non-destructive import of Countries & multi-MNC Networks from external source';

    public function handle(): int {
        $source = strtolower((string)$this->option('source') ?: 'itu');
        if ($source !== 'itu') { $this->error('Unsupported source'); return 1; }
        $label = 'ITU import';

        $url = 'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/mcc-mnc.csv';
        $csv = $this->fetch($url);
        if (!$csv) { $this->error('Cannot fetch ITU CSV'); return 1; }

        $lines = preg_split("/\r\n|\n|\r/", trim($csv));
        if (!$lines || count($lines) < 2) { $this->error('Empty CSV'); return 1; }
        $hdr = array_map('strtolower', str_getcsv(array_shift($lines)));
        $now = now();

        DB::transaction(function() use ($lines, $hdr, $label, $now) {
            foreach ($lines as $ln) {
                if ($ln==='') continue;
                $cols = str_getcsv($ln);
                $row  = array_combine($hdr, array_pad($cols, count($hdr), null));
                if (!$row) continue;

                $mcc = preg_replace('/\D+/','',(string)($row['mcc']??''));
                $mnc = preg_replace('/\D+/','',(string)($row['mnc']??''));
                $country = trim((string)($row['country']??''));
                $name = trim((string)($row['brand'] ?? ($row['operator'] ?? '')));

                if ($country==='' || $name==='' || $mcc==='' || $mnc==='') continue;

                // countries
                $countryId = DB::table('countries')->where('name',$country)->value('id');
                if (!$countryId) {
                    $countryId = DB::table('countries')->insertGetId([
                        'name'=>$country, 'iso2'=>substr(strtolower($country),0,2),
                        'created_at'=>$now, 'updated_at'=>$now
                    ]);
                } else {
                    DB::table('countries')->where('id',$countryId)->update(['updated_at'=>$now]);
                }

                // networks (unique by country_id + lower(name))
                $net = DB::table('networks')
                    ->where('country_id',$countryId)
                    ->whereRaw('lower(name)=lower(?)',[$name])
                    ->first();

                if (!$net) {
                    $networkId = DB::table('networks')->insertGetId([
                        'country_id'=>$countryId, 'name'=>$name,
                        'created_by_source'=>$label, 'updated_by_source'=>$label,
                        'created_at'=>$now, 'updated_at'=>$now
                    ]);
                } else {
                    DB::table('networks')->where('id',$net->id)->update([
                        'updated_by_source'=>$label,'updated_at'=>$now
                    ]);
                    $networkId = $net->id;
                }

                // mncs (unique by mcc_mnc)
                $mccmnc = $mcc.$mnc;
                $existing = DB::table('network_mncs')->where('mcc_mnc',$mccmnc)->first();
                if (!$existing) {
                    DB::table('network_mncs')->insert([
                        'network_id'=>$networkId,'mcc'=>$mcc,'mnc'=>$mnc,'mcc_mnc'=>$mccmnc,
                        'created_by_source'=>$label,'updated_by_source'=>$label,
                        'created_at'=>$now,'updated_at'=>$now
                    ]);
                } else {
                    DB::table('network_mncs')->where('id',$existing->id)->update([
                        'network_id'=>$networkId,'mcc'=>$mcc,'mnc'=>$mnc,'mcc_mnc'=>$mccmnc,
                        'updated_by_source'=>$label,'updated_at'=>$now
                    ]);
                }
            }
        });

        $this->info('Import finished (non-destructive).');
        return Command::SUCCESS;
    }

    private function fetch(string $url): ?string {
        $ua = "sms-procurement-platform/1.0";
        // 1) file_get_contents with UA
        $ctx = stream_context_create([
            'http'  => ['timeout'=>30, 'header'=>"User-Agent: $ua\r\n"],
            'https' => ['timeout'=>30, 'header'=>"User-Agent: $ua\r\n"]
        ]);
        $raw = @file_get_contents($url,false,$ctx);
        if($raw!==false && strlen($raw)>0) return $raw;

        // 2) curl extension
        if(function_exists('curl_init')){
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER=>true,
                CURLOPT_FOLLOWLOCATION=>true,
                CURLOPT_CONNECTTIMEOUT=>10,
                CURLOPT_TIMEOUT=>30,
                CURLOPT_USERAGENT=>$ua,
            ]);
            $data=curl_exec($ch);
            $http=(int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            if($http>=200 && $http<300 && $data) return $data;
        }

        // 3) CLI curl fallback
        $cmd = 'curl -fsSL --retry 3 --connect-timeout 10 -A '.escapeshellarg($ua).' '.escapeshellarg($url).' 2>/dev/null';
        $data = @shell_exec($cmd);
        if($data) return $data;

        return null;
    }
}
PHP

###############################################################################
# 2) Controller: pass --source from the UI
###############################################################################
mkdir -p app/Http/Controllers
cat > app/Http/Controllers/CarriersImportController.php <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

class CarriersImportController extends Controller {
    public function __construct(){ $this->middleware('auth'); }
    public function run(Request $r){
        $code = Artisan::call('carriers:import', [
            '--fresh'  => $r->boolean('fresh', false),
            '--source' => (string)$r->input('source','itu'),
        ]);
        return back()->with('status', "Import finished (code $code).\n".Artisan::output());
    }
}
PHP

###############################################################################
# 3) Networks index: layout (import source label + dropdown) + pagination
###############################################################################
mkdir -p resources/views/networks
cat > resources/views/networks/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2></x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <a href="{{ route('networks.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Network</a>

      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-2"
            onsubmit="return confirm('Run import from selected source? Local data will NOT be deleted.');">
        @csrf
        <input type="hidden" name="fresh" value="1">
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700">Fresh import</button>
        <span class="text-sm text-gray-600 ml-1">Import Source</span>
        <select name="source" class="rounded border px-3 py-2">
          <option value="itu" selected>ITU</option>
        </select>
      </form>
    </div>

    <form method="GET" class="flex flex-wrap items-center gap-2 mb-3">
      <input name="q" value="{{ request('q') }}" placeholder="Name…" class="rounded border px-3 py-2">
      <input name="country" value="{{ request('country') }}" placeholder="Country…" class="rounded border px-3 py-2">
      <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC…" class="rounded border px-3 py-2">
      <input name="mnc" value="{{ request('mnc') }}" placeholder="MNC…" class="rounded border px-3 py-2">
      <input name="mcc_mnc" value="{{ request('mcc_mnc') }}" placeholder="MCC-MNC…" class="rounded border px-3 py-2">
      <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
    </form>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">Network</th>
            <th class="px-3 py-2 text-left">MCC(s)</th>
            <th class="px-3 py-2 text-left">MNCs</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($networks as $n)
          @php
            $mccs = ($n->mncs ?? collect())->pluck('mcc')->filter()->unique();
            $mncs = ($n->mncs ?? collect())->pluck('mnc')->filter()->unique();
          @endphp
          <tr class="border-t">
            <td class="px-3 py-2">{{ $n->country_name }}</td>
            <td class="px-3 py-2">{{ $n->name }}</td>
            <td class="px-3 py-2">
              @foreach($mccs as $mcc)
                <span class="inline-block rounded bg-gray-100 px-2 py-0.5 mr-1">{{ $mcc }}</span>
              @endforeach
            </td>
            <td class="px-3 py-2">
              @foreach($mncs as $mnc)
                <span class="inline-block rounded bg-gray-100 px-2 py-0.5 mr-1">{{ $mnc }}</span>
              @endforeach
            </td>
            <td class="px-3 py-2 text-right">
              <a href="{{ route('networks.edit',$n) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
              <form method="POST" action="{{ route('networks.destroy',$n) }}" class="inline" onsubmit="return confirm('Delete this network?')">
                @csrf @method('DELETE')
                <button class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Delete</button>
              </form>
            </td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="flex items-center justify-between mt-3">
      <div class="text-sm text-gray-600">
        Showing {{ $networks->firstItem() }}–{{ $networks->lastItem() }} of {{ $networks->total() }}
      </div>
      <form method="GET" class="flex items-center gap-2">
        @foreach (request()->except('per') as $k=>$v) <input type="hidden" name="{{ $k }}" value="{{ $v }}"> @endforeach
        <select name="per" class="rounded border px-2 py-1" onchange="this.form.submit()">
          @foreach([20,50,100,1000] as $opt)
            <option value="{{ $opt }}" {{ (int)request('per', $per)===$opt?'selected':'' }}>{{ $opt }}/page</option>
          @endforeach
        </select>
      </form>
    </div>

    <div class="mt-2">
      {{ $networks->onEachSide(1)->withQueryString()->links() }}
    </div>
  </div>
</x-app-layout>
BLADE

###############################################################################
# 4) Networks edit + partial: single confirm on Save if any deletions checked
###############################################################################
cat > resources/views/networks/_form.blade.php <<'BLADE'
@php /* expects: $network, $countries, $primaryMcc */ @endphp
<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div>
    <label class="block text-sm font-medium mb-1">Network name</label>
    <input name="name" value="{{ old('name', $network->name) }}" class="w-full rounded border px-3 py-2" required>
    <div class="text-xs text-gray-500 mt-1">Primary MCC: <b>{{ $primaryMcc ?: '—' }}</b></div>
  </div>

  <div>
    <label class="block text-sm font-medium mb-1">Country</label>
    <select name="country_id" class="w-full rounded border px-3 py-2" required>
      @foreach($countries as $c)
        <option value="{{ $c->id }}" {{ (int)old('country_id', $network->country_id) === $c->id ? 'selected' : '' }}>{{ $c->name }}</option>
      @endforeach
    </select>
  </div>

  <div class="md:col-span-2">
    <label class="block text-sm font-medium mb-2">MNCs</label>
    <div id="mnc-rows" class="space-y-2">
      @foreach(($network->mncs ?? collect()) as $m)
      <div class="flex flex-wrap items-center gap-2 mnc-row">
        <input type="hidden" name="mncs_existing[{{ $m->id }}][id]" value="{{ $m->id }}">
        <div>
          <div class="text-xs text-gray-500 mb-0.5">MNC</div>
          <input name="mncs_existing[{{ $m->id }}][mnc]" value="{{ $m->mnc }}" class="rounded border px-3 py-2 w-28" autocomplete="off">
        </div>
        <div>
          <div class="text-xs text-gray-500 mb-0.5">MCC-MNC</div>
          <input value="{{ ($m->mcc ?? $primaryMcc).$m->mnc }}" class="rounded border px-3 py-2 bg-gray-50 w-36" readonly>
        </div>
        <label class="ml-2 text-sm inline-flex items-center gap-1">
          <input type="checkbox" name="mncs_existing[{{ $m->id }}][delete]">
          remove
        </label>
        <div class="text-xs text-gray-500 ml-2">
          Created: {{ optional($m->created_at)->format('Y-m-d H:i') }}
          @if($m->created_by_user_id) by User #{{ $m->created_by_user_id }} @elseif($m->created_by_source) by {{ $m->created_by_source }} @endif
          • Updated: {{ optional($m->updated_at)->format('Y-m-d H:i') }}
          @if($m->updated_by_user_id) by User #{{ $m->updated_by_user_id }} @elseif($m->updated_by_source) by {{ $m->updated_by_source }} @endif
        </div>
      </div>
      @endforeach
    </div>

    <div class="mt-3 flex items-center gap-2">
      <input id="mnc-add" placeholder="Type MNC and press Enter" class="rounded border px-3 py-2 w-60" autocomplete="off">
      <span class="text-xs text-gray-500">Primary MCC: <b>{{ $primaryMcc ?: '—' }}</b></span>
    </div>
    <div id="mnc-new-container" class="mt-2 space-y-2"></div>

    <script>
    (function(){
      // quick-add MNC
      const input = document.getElementById('mnc-add');
      const cont  = document.getElementById('mnc-new-container');
      const primary = @json($primaryMcc ?? '');
      input.addEventListener('keydown', function(e){
        if(e.key === 'Enter'){
          e.preventDefault();
          const raw = (this.value || '').trim();
          if(!raw) return;
          const mnc = raw.replace(/\D+/g,'');
          if(!mnc) { this.value=''; return; }
          const row = document.createElement('div');
          row.className = 'flex flex-wrap items-center gap-2';
          const a = document.createElement('input');
          a.name = 'mncs_new[]';
          a.value = mnc;
          a.className = 'rounded border px-3 py-2 w-28';
          const b = document.createElement('input');
          b.readOnly = true;
          b.value = (primary||'') + mnc;
          b.className = 'rounded border px-3 py-2 bg-gray-50 w-36';
          row.appendChild(a); row.appendChild(b);
          cont.appendChild(row);
          this.value='';
        }
      });
    })();
    </script>
  </div>
</div>
BLADE

cat > resources/views/networks/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2>
    <div class="text-sm text-gray-500">Primary MCC: <b>{{ $primaryMcc ?: '—' }}</b></div>
  </x-slot>

  <div class="py-6 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <form method="POST" action="{{ route('networks.update',$network) }}" class="space-y-4" data-network-edit>
      @csrf @method('PUT')
      @include('networks._form')

      <div class="flex items-center gap-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>

  <script>
  (function(){
    var f=document.querySelector('form[data-network-edit]');
    if(!f) return;
    f.addEventListener('submit',function(e){
      var n=f.querySelectorAll("input[type=checkbox][name$='[delete]']:checked").length;
      if(n>0 && !confirm('Remove '+n+' MNC(s)?')){ e.preventDefault(); }
    });
  })();
  </script>
</x-app-layout>
BLADE

###############################################################################
# 5) Warm caches
###############################################################################
$DC exec -T app sh -lc '
  php artisan optimize:clear && php artisan view:cache && php artisan route:cache
'
echo "OK: networks UI/import/pagination + controller source param are updated."
