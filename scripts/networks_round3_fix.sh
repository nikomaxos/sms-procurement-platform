#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

###############################################################################
# 0) Backfill command: migrate legacy networks.mcc/mnc -> network_mncs (one-off)
###############################################################################
mkdir -p app/Console/Commands

cat > app/Console/Commands/BackfillLegacyMncs.php <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class BackfillLegacyMncs extends Command {
    protected $signature = 'networks:backfill-mncs';
    protected $description = 'One-off: copy legacy networks.mcc/mnc into network_mncs if relation empty';

    public function handle(): int {
        $count = 0;
        DB::transaction(function() use (&$count){
            $rows = DB::table('networks')
                ->leftJoin('network_mncs','network_mncs.network_id','=','networks.id')
                ->select('networks.id','networks.country_id','networks.mcc','networks.mnc',
                         DB::raw('COUNT(network_mncs.id) as rel_count'))
                ->groupBy('networks.id','networks.country_id','networks.mcc','networks.mnc')
                ->get();
            foreach ($rows as $r) {
                if ($r->rel_count==0 && $r->mcc && $r->mnc) {
                    $mcc = preg_replace('/\D+/', '', (string)$r->mcc);
                    $mnc = preg_replace('/\D+/', '', (string)$r->mnc);
                    if ($mcc!=='' && $mnc!=='') {
                        $mccmnc = $mcc.$mnc;
                        DB::table('network_mncs')->updateOrInsert(
                            ['mcc_mnc'=>$mccmnc],
                            ['network_id'=>$r->id,'mcc'=>$mcc,'mnc'=>$mnc,
                             'created_by_source'=>'Backfill','updated_by_source'=>'Backfill',
                             'created_at'=>now(),'updated_at'=>now()]
                        );
                        $count++;
                    }
                }
            }
        });
        $this->info("Backfilled MNC rows: $count");
        return Command::SUCCESS;
    }
}
PHP

# Register command in Console Kernel if not present
php -r '
$f="app/Console/Kernel.php";
if (!file_exists($f)) {
  @mkdir(dirname($f),0777,true);
  file_put_contents($f, "<?php\nnamespace App\\Console;\nuse Illuminate\\Console\\Scheduling\\Schedule;\nuse Illuminate\\Foundation\\Console\\Kernel as ConsoleKernel;\nclass Kernel extends ConsoleKernel { protected function schedule(Schedule $s){} protected function commands(){ \$this->load(__DIR__.\'/Commands\'); }}");
}
$s=file_get_contents($f);
if (strpos($s,"BackfillLegacyMncs")===false) {
  $s=preg_replace("/class\\s+Kernel\\s+extends\\s+ConsoleKernel\\s*\\{/",
    "class Kernel extends ConsoleKernel { protected function commands(){ \$this->load(__DIR__.\'/Commands\'); }\n",
    $s,1);
  file_put_contents($f,$s);
}
'

###############################################################################
# 1) Importer: non-destructive upsert, mcc_mnc always set, --source option
###############################################################################
cat > app/Console/Commands/ImportCarriers.php <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--fresh} {--source=itu}';
    protected $description = 'Import Countries & Networks (multi-MNC) from selected source (non-destructive)';

    public function handle(): int {
        $source = strtolower((string)$this->option('source') ?: 'itu'); // only "itu" supported for now
        $label  = strtoupper($source).' import';
        $fresh  = (bool)$this->option('fresh'); // kept for UI but we DO NOT delete anything

        // Load ITU CSV (via onomondo repo format or musalbas-compatible)
        $csv = $this->fetch("https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/mcc-mnc.csv");
        if (!$csv) { $this->error('Failed to fetch ITU CSV'); return 1; }

        $lines = preg_split("/\r\n|\n|\r/", trim($csv));
        $hdr   = array_map('strtolower', str_getcsv(array_shift($lines)));

        $now = now();
        DB::transaction(function() use ($lines,$hdr,$label,$now) {
            foreach ($lines as $ln) {
                if ($ln==='') continue;
                $cols = str_getcsv($ln);
                $row  = array_combine($hdr, array_pad($cols, count($hdr), null));
                if (!$row) continue;

                // Column names in onomondo file: mcc,mnc,country,brand,operator ...
                $mcc = preg_replace('/\D+/','',(string)($row['mcc']??''));
                $mnc = preg_replace('/\D+/','',(string)($row['mnc']??''));
                $country = trim((string)($row['country']??''));
                $name = trim((string)($row['brand'] ?? ($row['operator'] ?? 'Unknown')));

                if ($country==='' || $mcc==='' || $mnc==='' || $name==='') continue;

                // country
                $countryId = DB::table('countries')->where('name',$country)->value('id');
                if (!$countryId) {
                    $countryId = DB::table('countries')->insertGetId([
                        'name'=>$country, 'iso2'=>substr(strtolower($country),0,2),
                        'created_at'=>$now, 'updated_at'=>$now
                    ]);
                } else {
                    DB::table('countries')->where('id',$countryId)->update(['updated_at'=>$now]);
                }

                // network (unique by country_id + name, case-insensitive)
                $network = DB::table('networks')
                    ->where('country_id',$countryId)
                    ->whereRaw('lower(name) = lower(?)',[$name])
                    ->first();

                if (!$network) {
                    $nid = DB::table('networks')->insertGetId([
                        'country_id'=>$countryId, 'name'=>$name,
                        'created_by_source'=>$label, 'updated_by_source'=>$label,
                        'created_at'=>$now, 'updated_at'=>$now
                    ]);
                    $networkId = $nid;
                } else {
                    DB::table('networks')->where('id',$network->id)
                        ->update(['updated_by_source'=>$label,'updated_at'=>$now]);
                    $networkId = $network->id;
                }

                // mnc row (unique by mcc_mnc)
                $mccmnc = $mcc.$mnc;
                $mrow = DB::table('network_mncs')->where('mcc_mnc',$mccmnc)->first();
                if (!$mrow) {
                    DB::table('network_mncs')->insert([
                        'network_id'=>$networkId,'mcc'=>$mcc,'mnc'=>$mnc,'mcc_mnc'=>$mccmnc,
                        'created_by_source'=>$label,'updated_by_source'=>$label,
                        'created_at'=>$now,'updated_at'=>$now
                    ]);
                } else {
                    // re-link to correct network/country if needed and refresh audit
                    DB::table('network_mncs')->where('id',$mrow->id)->update([
                        'network_id'=>$networkId,'mcc'=>$mcc,'mnc'=>$mnc,'mcc_mnc'=>$mccmnc,
                        'updated_by_source'=>$label,'updated_at'=>$now
                    ]);
                }
            }
        });

        $this->info("Import finished from $label (non-destructive).");
        return Command::SUCCESS;
    }

    private function fetch(string $url): ?string {
        $ctx = stream_context_create(['http'=>['timeout'=>30],'https'=>['timeout'=>30]]);
        $raw = @file_get_contents($url,false,$ctx);
        return $raw===false ? null : $raw;
    }
}
PHP

###############################################################################
# 2) Controller: ensure delete checkbox works; remove flagged filter
###############################################################################
cat > app/Http/Controllers/NetworksController.php <<'PHP'
<?php
namespace App\Http\Controllers;

use App\Models\Network;
use App\Models\NetworkMnc;
use App\Models\Country;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class NetworksController extends Controller {
    public function __construct(){ $this->middleware('auth'); }

    public function index(Request $r){
        $per = (int)($r->integer('per') ?: 20);
        $per = in_array($per,[20,50,100,1000],true) ? $per : 20;

        $q = Network::query()
            ->with(['country:id,name','mncs:id,network_id,mcc,mnc,mcc_mnc'])
            ->leftJoin('countries','countries.id','=','networks.country_id')
            ->leftJoin('network_mncs','network_mncs.network_id','=','networks.id')
            ->select('networks.*','countries.name as country_name', DB::raw('MIN(network_mncs.mcc_mnc) as min_mccmnc'))
            ->when($r->filled('q'), fn($qq)=>$qq->where('networks.name','ilike','%'.$r->q.'%'))
            ->when($r->filled('country'), fn($qq)=>$qq->where('countries.name','ilike','%'.$r->country.'%'))
            ->when($r->filled('mcc'), fn($qq)=>$qq->where('network_mncs.mcc',$r->mcc))
            ->when($r->filled('mnc'), fn($qq)=>$qq->where('network_mncs.mnc',$r->mnc))
            ->when($r->filled('mcc_mnc'), fn($qq)=>$qq->where('network_mncs.mcc_mnc','ilike','%'.$r->mcc_mnc.'%'))
            ->groupBy('networks.id','countries.name')
            ->orderBy('country_name')->orderBy('min_mccmnc');

        $networks = $q->paginate($per)->appends($r->all());
        return view('networks.index', compact('networks','per'));
    }

    public function create(){
        $countries = Country::orderBy('name')->get(['id','name']);
        $network = new Network();
        $network->setRelation('mncs', collect());
        $primaryMcc = $this->primaryMccForCountry(null);
        return view('networks.create', compact('network','countries','primaryMcc'));
    }

    public function edit(Network $network){
        $network->load(['mncs:id,network_id,mcc,mnc,mcc_mnc,created_at,updated_at,created_by_user_id,updated_by_user_id,created_by_source,updated_by_source','country.mccs']);
        $countries = Country::orderBy('name')->get(['id','name']);
        $primaryMcc = $this->primaryMccForCountry($network->country_id, $network);
        return view('networks.edit', compact('network','countries','primaryMcc'));
    }

    public function store(Request $r){ return $this->upsert($r, new Network()); }
    public function update(Request $r, Network $network){ return $this->upsert($r, $network); }

    private function upsert(Request $r, Network $network){
        $data = $r->validate([
            'name' => 'required|string|max:255',
            'country_id' => 'required|exists:countries,id',
            'mncs_existing' => 'array',
            'mncs_existing.*.mnc' => 'nullable|string|max:12',
            'mncs_existing.*.delete' => 'sometimes',
            'mncs_new' => 'array',
            'mncs_new.*' => 'nullable|string|max:12',
        ]);

        DB::transaction(function() use ($r, $network, $data) {
            $user = $r->user();
            $network->name = $data['name'];
            $network->country_id = $data['country_id'];
            $network->updated_by_user_id = $user?->id;
            $network->updated_by_source = null;
            if (!$network->exists) {
                $network->created_by_user_id = $user?->id;
                $network->created_by_source = null;
            }
            $network->save();

            $primaryMcc = $this->primaryMccForCountry($network->country_id, $network);

            foreach (($data['mncs_existing'] ?? []) as $id => $row) {
                $m = NetworkMnc::find($id);
                if(!$m || $m->network_id !== $network->id) continue;

                if (isset($row['delete'])) { // checkbox present -> remove
                    $m->delete();
                    continue;
                }

                $mnc = preg_replace('/\D+/','', (string)($row['mnc'] ?? ''));
                if ($mnc === '') { $m->delete(); continue; }

                $m->mcc = $m->mcc ?: $primaryMcc;
                $m->mnc = $mnc;
                $m->mcc_mnc = ($m->mcc ?: $primaryMcc).$mnc;
                $m->updated_by_user_id = $user?->id;
                $m->updated_by_source = null;
                $m->save();
            }

            foreach (($data['mncs_new'] ?? []) as $raw) {
                $mnc = preg_replace('/\D+/','', (string)$raw);
                if ($mnc==='') continue;
                $mcc = $primaryMcc ?: '';
                $mccmnc = $mcc.$mnc;
                if ($mccmnc==='') continue;
                NetworkMnc::updateOrCreate(
                    ['mcc_mnc'=>$mccmnc],
                    ['network_id'=>$network->id,'mcc'=>$mcc,'mnc'=>$mnc,'updated_by_user_id'=>$user?->id]
                );
            }
        });

        return redirect()->route('networks.edit', $network)->with('status','Saved.');
    }

    private function primaryMccForCountry(?int $countryId, ?Network $network=null): string {
        if ($countryId) {
            $row = DB::table('country_mccs')->where('country_id',$countryId)->orderBy('mcc')->first();
            if ($row && $row->mcc) return (string)$row->mcc;
        }
        if ($network && $network->relationLoaded('mncs') && $network->mncs->first()?->mcc) {
            return (string)$network->mncs->first()->mcc;
        }
        return '';
    }

    public function destroy(Network $network){
        $network->delete();
        return redirect()->route('networks.index')->with('status','Deleted.');
    }
}
PHP

###############################################################################
# 3) CarriersImportController: pass source to artisan
###############################################################################
cat > app/Http/Controllers/CarriersImportController.php <<'PHP'
<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

class CarriersImportController extends Controller {
  public function __construct(){ $this->middleware('auth'); }
  public function run(Request $r){
    $code = Artisan::call('carriers:import', [
      '--fresh' => $r->boolean('fresh',false),
      '--source' => $r->input('source','itu'),
    ]);
    return back()->with('status', "Import finished (code $code).\n".Artisan::output());
  }
}
PHP

###############################################################################
# 4) Views: networks index, form, edit (UI tweaks + source dropdown + confirm)
###############################################################################
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
            onsubmit="return confirm('Run import? Local data will NOT be deleted.');">
        @csrf
        <input type="hidden" name="fresh" value="1">
        <select name="source" class="rounded border px-3 py-2">
          <option value="itu" selected>ITU</option>
        </select>
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700">Fresh import</button>
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
          <tr class="border-t">
            <td class="px-3 py-2">{{ $n->country_name }}</td>
            <td class="px-3 py-2">{{ $n->name }}</td>
            <td class="px-3 py-2">
              @php $mccs = $n->mcc_list ?? collect(); @endphp
              @foreach($mccs as $mcc)
                <span class="inline-block rounded bg-gray-100 px-2 py-0.5 mr-1">{{ $mcc }}</span>
              @endforeach
            </td>
            <td class="px-3 py-2">
              @php $mncs = $n->mnc_list ?? collect(); @endphp
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
      <div class="text-sm text-gray-600">Showing {{ $networks->firstItem() }}–{{ $networks->lastItem() }} of {{ $networks->total() }}</div>
      <form method="GET" class="flex items-center gap-2">
        @foreach (request()->except('per') as $k=>$v) <input type="hidden" name="{{ $k }}" value="{{ $v }}"> @endforeach
        <select name="per" class="rounded border px-2 py-1" onchange="this.form.submit()">
          @foreach([20,50,100,1000] as $opt)<option value="{{ $opt }}" {{ (int)request('per', $per)===$opt?'selected':'' }}>{{ $opt }}/page</option>@endforeach
        </select>
      </form>
    </div>
  </div>
</x-app-layout>
BLADE

cat > resources/views/networks/_form.blade.php <<'BLADE'
@php
  // $network, $countries, $primaryMcc provided
@endphp

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
          <input type="checkbox" name="mncs_existing[{{ $m->id }}][delete]" onclick="if(this.checked && !confirm('Remove this MNC?')) this.checked=false;">
          remove
        </label>
        <div class="text-xs text-gray-500 ml-2">
          Created: {{ optional($m->created_at)->format('Y-m-d H:i') }}
          @if($m->created_by_user_id) by {{ optional($m->createdByUser)->name }} @elseif($m->created_by_source) by {{ $m->created_by_source }} @endif
          • Updated: {{ optional($m->updated_at)->format('Y-m-d H:i') }}
          @if($m->updated_by_user_id) by {{ optional($m->updatedByUser)->name }} @elseif($m->updated_by_source) by {{ $m->updated_by_source }} @endif
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
    <form method="POST" action="{{ route('networks.update',$network) }}" class="space-y-4">
      @csrf @method('PUT')
      @include('networks._form')
      <div class="flex items-center gap-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

###############################################################################
# 5) Run backfill + warm caches
###############################################################################
$DC exec -T app sh -lc '
  php artisan networks:backfill-mncs || true
  php artisan optimize:clear && php artisan view:cache && php artisan route:cache
'
echo "Done."
