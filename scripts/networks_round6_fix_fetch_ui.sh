#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> 1) Ensure NetworkMnc model exists and auto-computes mcc_mnc"
mkdir -p app/Models
cat > app/Models/NetworkMnc.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;

class NetworkMnc extends Model {
    protected $fillable = [
        'network_id','mcc','mnc','mcc_mnc',
        'marked_for_deletion','created_by_user','updated_by_user',
        'created_by_source','updated_by_source',
    ];
    protected $casts = [
        'marked_for_deletion'=>'boolean',
    ];
    protected static function booted(){
        static::saving(function($m){
            $mcc = trim((string)$m->mcc);
            $mnc = trim((string)$m->mnc);
            $m->mcc_mnc = $mcc.$mnc; // keep as provided (no zero-stripping/padding)
        });
    }
    public function network(){ return $this->belongsTo(Network::class); }
}
PHP

echo "==> 2) Harden ImportCarriers fetch (+ compute mcc_mnc explicitly)"
mkdir -p app/Console/Commands
cat > app/Console/Commands/ImportCarriers.php <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use App\Models\Country;
use App\Models\Network;
use App\Models\NetworkMnc;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--source=itu} {--fresh : clean helper tables but do NOT delete Networks}';
    protected $description = 'Import carriers (countries/networks/MNCs) from external datasets';

    public function handle(): int {
        $source = strtolower((string)$this->option('source') ?: 'itu');
        $fresh  = (bool)$this->option('fresh');

        if ($source !== 'itu') {
            $this->error("Unsupported source: {$source}");
            return 1;
        }

        // Optional light cleanup (do not delete networks)
        if ($fresh) {
            DB::table('network_mncs')->delete();
            DB::table('country_mccs')->delete();
            $this->info('Cleared network_mncs & country_mccs (networks kept).');
        }

        $csv = $this->fetchItuCsv();
        if ($csv === null) {
            $this->error('Cannot fetch ITU CSV');
            return 1;
        }

        [$hdr,$rows] = $this->parseCsv($csv);
        if (!$hdr || !$rows) {
            $this->error('Empty or invalid ITU CSV');
            return 1;
        }

        $map = array_change_key_case(array_flip($hdr), CASE_LOWER);
        $get = function(array $r, string $k): string {
            foreach([$k, ucfirst($k), strtoupper($k)] as $kk){
                if(isset($r[$kk]) && $r[$kk] !== null) return trim((string)$r[$kk]);
            }
            return '';
        };

        DB::transaction(function() use($rows,$map,$get){
            foreach ($rows as $r) {
                // Map common ITU headers
                $mcc = $get($r,'mcc');
                $mnc = $get($r,'mnc');
                $countryName = $get($r,'country') ?: $get($r,'country_name');
                $name = $get($r,'operator') ?: $get($r,'brand') ?: $get($r,'network') ?: 'Unknown';

                if ($mcc === '' || $mnc === '' || $countryName === '' || $name === 'Unknown') {
                    continue;
                }

                // Countries: iso may not exist in ITU dataset; keep NULL if unknown
                $iso = strtolower($get($r,'iso') ?: $get($r,'iso2'));
                if (strlen($iso) !== 2) $iso = null;

                $country = Country::firstOrCreate(
                    ['name'=>$countryName],
                    ['iso2'=>$iso]
                );

                // Networks: uniqueness by (country_id, lower(name))
                $net = Network::where('country_id',$country->id)
                    ->whereRaw('lower(name) = lower(?)', [$name])
                    ->first();

                if (!$net) {
                    $net = Network::create([
                        'country_id'=>$country->id,
                        'name'=>$name,
                        'created_by_source'=>'ITU import',
                    ]);
                } else {
                    $net->updated_by_source = 'ITU import';
                    $net->save();
                }

                // Keep country_mccs helper
                DB::table('country_mccs')->updateOrInsert(
                    ['mcc'=>$mcc],
                    ['country_id'=>$country->id, 'updated_at'=>now(), 'created_at'=>now()]
                );

                // MNC line (auto sets mcc_mnc via model hook)
                NetworkMnc::firstOrCreate(
                    ['network_id'=>$net->id, 'mcc'=>$mcc, 'mnc'=>$mnc],
                    ['created_by_source'=>'ITU import']
                );
            }
        });

        $this->info("Done. Countries: ".Country::count()." | Networks: ".Network::count()." | MNC rows: ".NetworkMnc::count());
        return 0;
    }

    private function parseCsv(string $csv): array {
        $lines = preg_split("/\r\n|\n|\r/", trim($csv));
        if (!$lines || count($lines) < 2) return [[],[]];
        $hdr = str_getcsv(array_shift($lines));
        $rows = [];
        foreach ($lines as $ln) {
            if ($ln==='') continue;
            $cols = str_getcsv($ln);
            $row = [];
            foreach ($hdr as $i => $h) {
                $row[$h] = $cols[$i] ?? null;
            }
            $rows[] = $row;
        }
        return [$hdr, $rows];
    }

    private function fetchItuCsv(): ?string {
        $urls = [
            // CDN first (often bypasses ISP blocks on raw.githubusercontent)
            'https://cdn.jsdelivr.net/gh/onomondo/mcc-mnc-itu/mcc-mnc.csv',
            // Raw on both common default branches
            'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/mcc-mnc.csv',
            'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/mcc-mnc.csv',
        ];
        foreach ($urls as $u) {
            // try file_get_contents
            $ctx = stream_context_create([
                'http'=>['timeout'=>25,'header'=>"User-Agent: ITU-import/1.0\r\n"],
                'https'=>['timeout'=>25,'header'=>"User-Agent: ITU-import/1.0\r\n"],
            ]);
            $raw = @file_get_contents($u,false,$ctx);
            if ($raw && strlen($raw) > 1000) return $raw;

            // try CLI curl if present
            $out = @shell_exec('command -v curl >/dev/null 2>&1 && curl -fsSL --max-time 25 -A "ITU-import/1.0" '.escapeshellarg($u).' || true');
            if ($out && strlen($out) > 1000) return $out;
        }
        return null;
    }
}
PHP

echo "==> 3) Networks edit view: single confirm on Save (only if some MNCs are checked), show readonly MCC-MNC per row, quick add by Enter"
cat > resources/views/networks/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2></x-slot>
  <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
    <form id="network-form" method="POST" action="{{ route('networks.update', $network) }}">
      @csrf @method('PUT')

      <div class="bg-white rounded border p-4 mb-4">
        <div class="grid md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Country</label>
            <input class="mt-1 w-full rounded border px-3 py-2 bg-gray-100" value="{{ $network->country->name }}" readonly>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Primary MCC</label>
            <input class="mt-1 w-full rounded border px-3 py-2" name="primary_mcc" value="{{ old('primary_mcc', $primaryMcc ?? '') }}">
            <p class="text-xs text-gray-500 mt-1">Also shown below the network name.</p>
          </div>
        </div>
        <div class="mt-4">
          <label class="block text-sm font-medium text-gray-700">Network Name</label>
          <input class="mt-1 w-full rounded border px-3 py-2" name="name" value="{{ old('name',$network->name) }}" required>
          <div class="text-sm text-gray-500 mt-1">Primary MCC: <span class="font-mono">{{ old('primary_mcc', $primaryMcc ?? '') }}</span></div>
        </div>
      </div>

      <div class="bg-white rounded border p-4 mb-4">
        <div class="flex items-center justify-between mb-3">
          <div class="text-lg font-semibold">MNCs</div>
          <div class="flex items-center gap-2">
            <input id="quick-mnc" type="text" placeholder="Add MNC then Enter" class="rounded border px-3 py-2">
            <button type="button" id="add-mnc" class="rounded bg-blue-600 text-white px-3 py-2">Add</button>
          </div>
        </div>

        <div id="mncs-list" class="space-y-3">
          @php $i=0; @endphp
          @foreach($network->mncs as $m)
            <div class="grid md:grid-cols-4 gap-3 items-end border rounded p-3">
              <div>
                <label class="block text-sm font-medium">MCC</label>
                <input name="mncs[{{ $i }}][mcc]" value="{{ $m->mcc }}" class="mt-1 w-full rounded border px-3 py-2">
              </div>
              <div>
                <label class="block text-sm font-medium">MNC</label>
                <input name="mncs[{{ $i }}][mnc]" value="{{ $m->mnc }}" class="mt-1 w-full rounded border px-3 py-2">
                <input type="hidden" name="mncs[{{ $i }}][id]" value="{{ $m->id }}">
              </div>
              <div>
                <label class="block text-sm font-medium">MCC-MNC (auto)</label>
                <input value="{{ $m->mcc.$m->mnc }}" class="mt-1 w-full rounded border px-3 py-2 bg-gray-100" readonly>
              </div>
              <div class="flex items-center gap-2">
                <label class="text-sm"><input type="checkbox" name="remove_mnc[]" value="{{ $m->id }}"> Remove</label>
              </div>
            </div>
            @php $i++; @endphp
          @endforeach
        </div>
      </div>

      <div class="bg-white rounded border p-4 mb-4 grid md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Created at</label>
          <input class="mt-1 w-full rounded border px-3 py-2 bg-gray-100" value="{{ optional($network->created_at)->format('Y-m-d H:i') }} — {{ $network->created_by_user ?? $network->created_by_source }}" readonly>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Updated at</label>
          <input class="mt-1 w-full rounded border px-3 py-2 bg-gray-100" value="{{ optional($network->updated_at)->format('Y-m-d H:i') }} — {{ $network->updated_by_user ?? $network->updated_by_source }}" readonly>
        </div>
      </div>

      <div class="flex items-center gap-3">
        <button class="rounded bg-blue-600 text-white px-4 py-2">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded bg-gray-200 px-4 py-2">Cancel</a>
      </div>
    </form>
  </div>

  <script>
  (function(){
    const list = document.getElementById('mncs-list');
    const input = document.getElementById('quick-mnc');
    const addBtn = document.getElementById('add-mnc');
    let idx = {{ count($network->mncs) }};

    function addMncRow(val){
      const mnc = (val||'').trim();
      if(!mnc) return;
      const html = `
        <div class="grid md:grid-cols-4 gap-3 items-end border rounded p-3">
          <div>
            <label class="block text-sm font-medium">MCC</label>
            <input name="mncs[${idx}][mcc]" value="{{ old('primary_mcc', $primaryMcc ?? '') }}" class="mt-1 w-full rounded border px-3 py-2">
          </div>
          <div>
            <label class="block text-sm font-medium">MNC</label>
            <input name="mncs[${idx}][mnc]" value="${mnc}" class="mt-1 w-full rounded border px-3 py-2">
          </div>
          <div>
            <label class="block text-sm font-medium">MCC-MNC (auto)</label>
            <input value="{{ old('primary_mcc', $primaryMcc ?? '') }}${mnc}" class="mt-1 w-full rounded border px-3 py-2 bg-gray-100" readonly>
          </div>
          <div class="flex items-center gap-2">
            <label class="text-sm"><input type="checkbox" name="remove_mnc[]" value="new-${idx}"> Remove</label>
          </div>
        </div>`;
      const wrap = document.createElement('div');
      wrap.innerHTML = html;
      list.appendChild(wrap.firstElementChild);
      idx++;
    }

    addBtn.addEventListener('click', () => { addMncRow(input.value); input.value=''; });
    input.addEventListener('keydown', (e)=>{ if(e.key==='Enter'){ e.preventDefault(); addMncRow(input.value); input.value=''; }});

    document.getElementById('network-form').addEventListener('submit', function(e){
      const anyRemoval = document.querySelectorAll('input[name="remove_mnc[]"]:checked').length > 0;
      if (anyRemoval && !confirm('Remove the checked MNCs?')) {
        e.preventDefault();
      }
    });
  })();
  </script>
</x-app-layout>
BLADE

echo "==> 4) Networks index view: Fresh Import + labeled source selector on top-left, pagination at bottom"
cat > resources/views/networks/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2></x-slot>
  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-2">
        @csrf
        <input type="hidden" name="fresh" value="1">
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700">Fresh Import</button>
        <span class="text-sm text-gray-600">Import Source</span>
        <select name="source" class="rounded border px-3 py-2">
          <option value="itu" {{ old('source','itu')==='itu' ? 'selected' : '' }}>ITU</option>
        </select>
      </form>

      <form method="GET" class="flex items-center gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Search name…" class="rounded border px-3 py-2">
        <input name="country" value="{{ request('country') }}" placeholder="Country…" class="rounded border px-3 py-2">
        <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC…" class="rounded border px-3 py-2">
        <input name="mnc" value="{{ request('mnc') }}" placeholder="MNC…" class="rounded border px-3 py-2">
        <input name="mcc_mnc" value="{{ request('mcc_mnc') }}" placeholder="MCC-MNC…" class="rounded border px-3 py-2">
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Filter</button>
      </form>

      <a href="{{ route('networks.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Network</a>
    </div>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">Network</th>
            <th class="px-3 py-2 text-left">MCC</th>
            <th class="px-3 py-2 text-left">MNCs</th>
            <th class="px-3 py-2 text-left">MCC-MNCs</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($networks as $n)
          <tr class="border-t">
            <td class="px-3 py-2">{{ $n->country->name }}</td>
            <td class="px-3 py-2">{{ $n->name }}</td>
            <td class="px-3 py-2">{{ $n->primary_mcc }}</td>
            <td class="px-3 py-2">
              @php $mncs = $n->mncs->pluck('mnc')->filter()->implode(', '); @endphp
              {{ $mncs }}
            </td>
            <td class="px-3 py-2">
              @php $mm = $n->mncs->map(fn($m)=>$m->mcc.$m->mnc)->implode(', '); @endphp
              {{ $mm }}
            </td>
            <td class="px-3 py-2 text-right">
              <a href="{{ route('networks.edit',$n) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
            </td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-3 flex items-center justify-between">
      <form method="GET" class="flex items-center gap-2">
        @foreach(request()->except('per','page') as $k=>$v)
          <input type="hidden" name="{{ $k }}" value="{{ $v }}">
        @endforeach
        <label class="text-sm">Per page</label>
        <select name="per" class="rounded border px-2 py-1" onchange="this.form.submit()">
          @foreach([20,50,100,1000] as $opt)
            <option value="{{ $opt }}" {{ (int)request('per',20)===$opt ? 'selected' : '' }}>{{ $opt }}</option>
          @endforeach
        </select>
      </form>
      <div>{{ $networks->withQueryString()->links() }}</div>
    </div>
  </div>
</x-app-layout>
BLADE

echo "==> 5) Controller: ensure NetworksController@index respects country alpha + mcc_mnc secondary sort and passes per-page"
php -r '
$f="app/Http/Controllers/NetworksController.php";
if(!file_exists($f)){ exit(0); }
$s=file_get_contents($f);
$s=preg_replace("/function\\s+index\\s*\\([^\\)]*\\)\\s*\\{[\\s\\S]*\\}/",
"function index(\\Illuminate\\Http\\Request $r){
    $per = max(1, min(1000, (int)$r->query(\"per\",20)));
    $q = \\App\\Models\\Network::with([\"country\",\"mncs\"])
        ->when($r->filled(\"q\"), fn($qq)=>$qq->where(\"name\",\"ilike\",\"%\".$r->q.\"%\")) 
        ->when($r->filled(\"country\"), fn($qq)=>$qq->whereHas(\"country\", fn($c)=>$c->where(\"name\",\"ilike\",\"%\".trim($r->country).\"%\")))
        ->when($r->filled(\"mcc\"), fn($qq)=>$qq->whereHas(\"mncs\", fn($m)=>$m->where(\"mcc\", trim($r->mcc))))
        ->when($r->filled(\"mnc\"), fn($qq)=>$qq->whereHas(\"mncs\", fn($m)=>$m->where(\"mnc\", trim($r->mnc))))
        ->when($r->filled(\"mcc_mnc\"), fn($qq)=>$qq->whereHas(\"mncs\", fn($m)=>$m->where(\"mcc_mnc\",\"ilike\",\"%\".trim($r->mcc_mnc).\"%\")))
        ->join(\"countries\",\"countries.id\",\"=\",\"networks.country_id\")
        ->orderBy(\"countries.name\")
        ->orderByRaw(\"(select coalesce(min(m.mcc||m.mnc), '') from network_mncs m where m.network_id = networks.id) asc\")
        ->select(\"networks.*\");
    $networks = $q->paginate($per)->appends($r->all());
    return view(\"networks.index\", compact(\"networks\"));
}", $s, 1);
file_put_contents($f,$s);
'

echo "==> 6) CarriersImportController: forward source"
mkdir -p app/Http/Controllers
cat > app/Http/Controllers/CarriersImportController.php <<'PHP'
<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

class CarriersImportController extends Controller {
  public function __construct(){ $this->middleware('auth'); }
  public function run(Request $r){
    $args = [];
    if ($r->boolean('fresh')) $args['--fresh'] = true;
    if ($r->filled('source')) $args['--source'] = $r->input('source');
    $code = Artisan::call('carriers:import', $args);
    return back()->with('status', "Import finished (code {$code}).\n".Artisan::output());
  }
}
PHP

echo "==> 7) Warm caches"
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "Done: resilient ITU fetch + UI fixes + pagination + save-time confirm."
