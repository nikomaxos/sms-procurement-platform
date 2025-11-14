#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

ts="$(date +%F_%H-%M-%S)"
echo "==> 0) Back up touched files"
for f in \
  app/Console/Commands/ImportCarriers.php \
  app/Http/Controllers/NetworksController.php \
  app/Http/Controllers/CarriersImportController.php \
  app/Models/NetworkMnc.php \
  resources/views/networks/index.blade.php \
  resources/views/networks/edit.blade.php \
; do [ -f "$f" ] && cp -a "$f" "$f.bak.$ts" || true; done

###############################################################################
# 1) Model: NetworkMnc – auto-compute mcc_mnc
###############################################################################
mkdir -p app/Models
cat > app/Models/NetworkMnc.php <<'PHP'
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NetworkMnc extends Model {
    protected $fillable = ['network_id','mcc','mnc','mcc_mnc','removed','created_by_user','updated_by_user','created_by_source','updated_by_source'];
    protected $casts = ['removed'=>'bool'];

    protected static function booted() {
        static::saving(function (self $m) {
            $mcc = trim((string)$m->mcc);
            $mnc = trim((string)$m->mnc);
            // keep leading zeros in MNC (treat as text)
            $m->mcc_mnc = $mcc.$mnc;
        });
    }

    public function network(){ return $this->belongsTo(Network::class); }
}
PHP

###############################################################################
# 2) Importer: resilient ITU fetch + local fallback + upsert-only merge
###############################################################################
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
    protected $signature = 'carriers:import {--source=itu} {--fresh}';
    protected $description = 'Upsert carriers from a source (itu|musalbas). --fresh now means "rebuild from source WITHOUT deletions".';

    public function handle(): int {
        $source = strtolower((string)$this->option('source') ?: 'itu');
        $fresh  = (bool)$this->option('fresh');

        $rows = [];
        if ($source === 'itu') {
            $rows = $this->loadITU();
        } elseif ($source === 'musalbas') {
            $rows = $this->loadMusalbas();
        } else {
            $this->error("Unknown source '$source'");
            return 1;
        }
        if (!$rows) { $this->error("Cannot fetch ".strtoupper($source)." CSV"); return 1; }

        $createdCountries = $createdNetworks = $createdMncs = 0;
        $updatedNetworks = $updatedMncs = 0;

        DB::transaction(function () use ($rows, $source, &$createdCountries, &$createdNetworks, &$createdMncs, &$updatedNetworks, &$updatedMncs) {
            foreach ($rows as $r) {
                $countryName = trim($r['country'] ?? '');
                $iso2 = strtolower(trim($r['iso2'] ?? ''));
                if (strlen($iso2) !== 2) $iso2 = null; // sanitize 'n/a' etc.

                $mcc = trim((string)($r['mcc'] ?? ''));
                $mnc = trim((string)($r['mnc'] ?? ''));
                $brand = trim((string)($r['name'] ?? ($r['brand'] ?? ($r['operator'] ?? 'Unknown'))));
                if ($countryName === '' || $mcc === '' || $mnc === '' || $brand === '') continue;

                $country = Country::firstOrCreate(
                    ['name' => $countryName],
                    ['iso2' => $iso2]
                );
                if ($country->wasRecentlyCreated) $createdCountries++;

                // Merge by (country_id, lower(name))
                $network = Network::where('country_id',$country->id)
                    ->whereRaw('lower(name) = lower(?)', [$brand])
                    ->first();

                if (!$network) {
                    $network = Network::create([
                        'country_id' => $country->id,
                        'name'       => $brand,
                        'created_by_source' => strtoupper($source).' import',
                        'updated_by_source' => strtoupper($source).' import',
                    ]);
                    $createdNetworks++;
                } else {
                    $network->updated_by_source = strtoupper($source).' import';
                    $network->save();
                    $updatedNetworks++;
                }

                // Upsert MNC under this network
                $m = NetworkMnc::where('mcc', $mcc)->where('mnc',$mnc)->first();
                if (!$m) {
                    $m = new NetworkMnc([
                        'network_id' => $network->id,
                        'mcc'        => $mcc,
                        'mnc'        => $mnc,
                        'created_by_source' => strtoupper($source).' import',
                        'updated_by_source' => strtoupper($source).' import',
                    ]);
                    $m->save();
                    $createdMncs++;
                } else {
                    // Re-parent if needed
                    if ((int)$m->network_id !== (int)$network->id) {
                        $m->network_id = $network->id;
                    }
                    $m->updated_by_source = strtoupper($source).' import';
                    $m->save();
                    $updatedMncs++;
                }
            }
        });

        $this->info("Done: countries +$createdCountries, networks +$createdNetworks/~$updatedNetworks, mncs +$createdMncs/~$updatedMncs");
        return 0;
    }

    /** Load ITU CSV via multiple raw URLs, then local fallback. */
    private function loadITU(): array {
        $urls = [
            // Common GitHub raw patterns (try both branches and paths)
            'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/refs/heads/main/mcc-mnc-itu.csv',
            'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/mcc-mnc-itu.csv',
            'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/mcc-mnc-itu.csv',
            'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/itu.csv',
            'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/itu.csv',
        ];
        foreach ($urls as $u) {
            if ($csv = $this->fetch($u)) {
                $rows = $this->parseFlexibleCsv($csv);
                if ($rows) return $rows;
            }
        }
        // Local fallback (you can drop a CSV here)
        $local = storage_path('app/carriers/itu/mcc_mnc_itu.csv');
        if (is_file($local)) {
            $rows = $this->parseFlexibleCsv(file_get_contents($local));
            if ($rows) return $rows;
        }
        return [];
    }

    /** Load from musalbas (JSON first, CSV fallback). */
    private function loadMusalbas(): array {
        $json = $this->fetch('https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json');
        if ($json) {
            $src = json_decode($json, true);
            $rows = [];
            if (is_array($src)) foreach ($src as $r) {
                $rows[] = [
                    'country' => $r['country'] ?? ($r['country_name'] ?? ''),
                    'iso2'    => strtolower($r['iso'] ?? ($r['iso2'] ?? '')),
                    'mcc'     => (string)($r['mcc'] ?? ''),
                    'mnc'     => (string)($r['mnc'] ?? ''),
                    'name'    => $r['brand'] ?? ($r['operator'] ?? ($r['network'] ?? 'Unknown')),
                ];
            }
            if ($rows) return $rows;
        }
        $csv = $this->fetch('https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.csv');
        return $csv ? $this->parseFlexibleCsv($csv) : [];
    }

    private function fetch(string $url): ?string {
        $ctx = stream_context_create([
            'http'  => ['timeout'=>30, 'ignore_errors'=>true, 'header'=>"User-Agent: carriers-import/1.0\r\n"],
            'https' => ['timeout'=>30, 'ignore_errors'=>true, 'header'=>"User-Agent: carriers-import/1.0\r\n"]
        ]);
        $raw = @file_get_contents($url, false, $ctx);
        if ($raw === false || strlen((string)$raw) < 64) return null; // avoid tiny 404 pages
        return $raw;
    }

    private function parseFlexibleCsv(string $csv): array {
        $lines = preg_split("/\r\n|\n|\r/", trim($csv));
        if (!$lines || count($lines) < 2) return [];
        $hdr = array_map(fn($h)=>strtolower(trim($h)), str_getcsv(array_shift($lines)));
        $rows = [];
        foreach ($lines as $ln) {
            if ($ln==='') continue;
            $cols = str_getcsv($ln);
            $row  = array_combine($hdr, array_pad($cols, count($hdr), null));
            if (!$row) continue;
            // Map common header variants
            $country = $row['country'] ?? ($row['country_name'] ?? ($row['territory'] ?? ''));
            $iso2    = strtolower($row['iso'] ?? ($row['iso2'] ?? ($row['alpha_2'] ?? '')));
            $mcc     = (string)($row['mcc'] ?? '');
            $mnc     = (string)($row['mnc'] ?? ($row['network_code'] ?? ''));
            $name    = $row['name'] ?? ($row['brand'] ?? ($row['operator'] ?? ($row['network'] ?? '')));
            if ($country && $mcc !== '' && $mnc !== '' && $name) {
                $rows[] = compact('country','iso2','mcc','mnc','name');
            }
        }
        return $rows;
    }
}
PHP

###############################################################################
# 3) CarriersImportController: forward source from networks index form
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
    $source = $r->string('source')->lower()->value() ?: 'itu';
    $fresh  = $r->boolean('fresh', false);
    $code = Artisan::call('carriers:import', ['--source'=>$source, '--fresh'=>$fresh]);
    return back()->with('status', "Import finished (code $code).\n".Artisan::output());
  }
}
PHP

###############################################################################
# 4) NetworksController@index: fix sorting & filters; keep pagination links
###############################################################################
cat > app/Http/Controllers/NetworksController.php <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Network;

class NetworksController extends Controller {
    public function __construct(){ $this->middleware('auth'); }

    public function index(Request $r){
        $per = in_array((int)$r->input('per'), [20,50,100,1000], true) ? (int)$r->input('per') : 20;

        $q = Network::query()
            ->with(['country','mncs'])
            ->join('countries','countries.id','=','networks.country_id')
            ->select('networks.*');

        if ($r->filled('q')) {
            $q->where('networks.name','ilike','%'.$r->q.'%');
        }
        if ($r->filled('country')) {
            $q->where('countries.name','ilike','%'.$r->country.'%');
        }
        if ($r->filled('mcc')) {
            $q->whereExists(function($sub) use ($r){
                $sub->from('network_mncs as nm')->whereColumn('nm.network_id','networks.id')->where('nm.mcc',$r->mcc);
            });
        }
        if ($r->filled('mnc')) {
            $q->whereExists(function($sub) use ($r){
                $sub->from('network_mncs as nm')->whereColumn('nm.network_id','networks.id')->where('nm.mnc',$r->mnc);
            });
        }
        if ($r->filled('mcc_mnc')) {
            $like = '%'.$r->mcc_mnc.'%';
            $q->whereExists(function($sub) use ($like){
                $sub->from('network_mncs as nm')->whereColumn('nm.network_id','networks.id')->where('nm.mcc_mnc','ilike',$like);
            });
        }

        // Sort: country A-Z, then by first MCC+MNC (via correlated subselect; no stray alias)
        $q->orderBy('countries.name','asc')
          ->orderByRaw("(select coalesce(min(nm.mcc::text || nm.mnc::text),'') from network_mncs nm where nm.network_id = networks.id) asc");

        $networks = $q->paginate($per)->appends($r->all());
        return view('networks.index', compact('networks'));
    }

    public function create(){ abort(404); } // unchanged here
    public function store(Request $r){ abort(404); }
    public function edit(\App\Models\Network $network){
        $network->load(['country','mncs']);
        return view('networks.edit', compact('network'));
    }
    public function update(Request $r, \App\Models\Network $network){
        $network->name = $r->string('name')->value() ?: $network->name;
        $network->save();

        $primary_mcc = $r->string('primary_mcc')->value();
        if ($primary_mcc === '') {
            $primary_mcc = optional($network->mncs->first())->mcc ?: '';
        }

        $incoming = $r->input('mncs', []);
        $toDelete = [];

        foreach ($incoming as $row) {
            $id   = $row['id']   ?? null;
            $mnc  = trim((string)($row['mnc'] ?? ''));
            $drop = !empty($row['remove']);

            if ($id) {
                $m = \App\Models\NetworkMnc::find($id);
                if ($m) {
                    if ($drop) { $toDelete[] = $m->id; continue; }
                    $m->mcc = $primary_mcc;
                    $m->mnc = $mnc;
                    $m->save();
                }
            } else {
                if ($drop || $mnc==='') continue;
                $m = new \App\Models\NetworkMnc([
                    'network_id'=>$network->id,
                    'mcc'=>$primary_mcc,
                    'mnc'=>$mnc,
                ]);
                $m->save();
            }
        }

        if ($toDelete) {
            \App\Models\NetworkMnc::whereIn('id',$toDelete)->delete();
        }

        return redirect()->route('networks.edit',$network)->with('status','Saved.');
    }
}
PHP

###############################################################################
# 5) Views: networks index + edit (UI: import source, pagination bottom,
#           show existing MNCs, readonly MCC-MNC, quick add, single confirm)
###############################################################################
mkdir -p resources/views/networks

# INDEX
cat > resources/views/networks/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2></x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <!-- Import form (left), with labeled source selector -->
      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-2">
        @csrf
        <input type="hidden" name="fresh" value="1">
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700">Fresh import</button>
        <label class="text-sm text-gray-600">Import Source</label>
        <select name="source" class="rounded border px-2 py-2">
          <option value="itu" {{ request('source','itu')==='itu'?'selected':'' }}>ITU</option>
          <option value="musalbas" {{ request('source')==='musalbas'?'selected':'' }}>Musalbas (community)</option>
        </select>
      </form>

      <!-- Filters -->
      <form method="GET" class="flex flex-wrap items-center gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Search network…" class="rounded border px-3 py-2">
        <input name="country" value="{{ request('country') }}" placeholder="Country" class="rounded border px-3 py-2">
        <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC" class="rounded border px-3 py-2">
        <input name="mnc" value="{{ request('mnc') }}" placeholder="MNC" class="rounded border px-3 py-2">
        <input name="mcc_mnc" value="{{ request('mcc_mnc') }}" placeholder="MCC-MNC" class="rounded border px-3 py-2">
        <select name="per" class="rounded border px-2 py-2">
          @foreach([20,50,100,1000] as $p)<option value="{{ $p }}" {{ (int)request('per',20)===$p?'selected':'' }}>{{ $p }}/page</option>@endforeach
        </select>
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      </form>
    </div>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">Network</th>
            <th class="px-3 py-2 text-left">MCC</th>
            <th class="px-3 py-2 text-left">MNCs</th>
            <th class="px-3 py-2 text-left">MCC-MNC</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($networks as $n)
          @php
            $mncs = $n->mncs ? $n->mncs->sortBy('mnc') : collect();
            $primary_mcc = optional($mncs->first())->mcc;
            $mnc_list = $mncs->pluck('mnc')->implode(', ');
            $mccmnc_list = $mncs->map(fn($m)=>$m->mcc.$m->mnc)->implode(', ');
          @endphp
          <tr class="border-t">
            <td class="px-3 py-2">{{ optional($n->country)->name }}</td>
            <td class="px-3 py-2">{{ $n->name }}</td>
            <td class="px-3 py-2">{{ $primary_mcc }}</td>
            <td class="px-3 py-2">{{ $mnc_list }}</td>
            <td class="px-3 py-2">{{ $mccmnc_list }}</td>
            <td class="px-3 py-2 text-right"><a href="{{ route('networks.edit',$n) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a></td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">
      {{ $networks->links() }}
    </div>
  </div>
</x-app-layout>
BLADE

# EDIT
cat > resources/views/networks/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2></x-slot>

  <div class="py-6 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <form method="POST" action="{{ route('networks.update', $network) }}" id="netForm">
      @csrf
      @method('PUT')

      <div class="bg-white rounded border p-4 space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">Network Name</label>
            <input name="name" value="{{ old('name',$network->name) }}" class="w-full rounded border px-3 py-2">
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">Country</label>
            <input value="{{ optional($network->country)->name }}" class="w-full rounded border px-3 py-2 bg-gray-50" readonly>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">Primary MCC</label>
            @php $primary = optional($network->mncs->first())->mcc; @endphp
            <input name="primary_mcc" value="{{ old('primary_mcc',$primary) }}" class="w-full rounded border px-3 py-2">
          </div>
        </div>

        <div class="pt-2">
          <div class="flex items-center justify-between">
            <div class="text-sm text-gray-600">MNCs (press Enter to add)</div>
            <input id="quickMnc" placeholder="Type MNC and press Enter" class="rounded border px-3 py-2">
          </div>

          <div id="mncs" class="mt-3 space-y-2">
            @php $rows = old('mncs'); @endphp
            @if (is_array($rows))
              @foreach ($rows as $i => $r)
                <x-mnc-row :row="$r"/>
              @endforeach
            @else
              @foreach ($network->mncs->sortBy('mnc') as $m)
                <div class="grid grid-cols-12 gap-2 items-center border rounded p-2">
                  <input type="hidden" name="mncs[][id]" value="{{ $m->id }}">
                  <div class="col-span-2">
                    <label class="block text-xs text-gray-500 mb-1">MNC</label>
                    <input name="mncs[][mnc]" value="{{ $m->mnc }}" class="w-full rounded border px-2 py-1">
                  </div>
                  <div class="col-span-3">
                    <label class="block text-xs text-gray-500 mb-1">MCC-MNC</label>
                    <input value="{{ $m->mcc.$m->mnc }}" class="w-full rounded border px-2 py-1 bg-gray-50" readonly>
                  </div>
                  <div class="col-span-3">
                    <label class="block text-xs text-gray-500 mb-1">Created / Updated by</label>
                    <input value="{{ $m->created_by_source ?? $m->created_by_user ?? '' }} / {{ $m->updated_by_source ?? $m->updated_by_user ?? '' }}" class="w-full rounded border px-2 py-1 bg-gray-50" readonly>
                  </div>
                  <div class="col-span-3">
                    <label class="block text-xs text-gray-500 mb-1">Created / Updated at</label>
                    <input value="{{ optional($m->created_at)->format('Y-m-d H:i') }} / {{ optional($m->updated_at)->format('Y-m-d H:i') }}" class="w-full rounded border px-2 py-1 bg-gray-50" readonly>
                  </div>
                  <div class="col-span-1 text-right">
                    <label class="block text-xs text-gray-500 mb-1">Remove</label>
                    <input type="checkbox" class="mnc-remove">
                    <input type="hidden" name="mncs[][remove]" value="0">
                  </div>
                </div>
              @endforeach
            @endif
          </div>
        </div>

        <div class="flex justify-end gap-2">
          <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Back</a>
          <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        </div>
      </div>
    </form>
  </div>

  <template id="rowTpl">
    <div class="grid grid-cols-12 gap-2 items-center border rounded p-2">
      <div class="col-span-2">
        <label class="block text-xs text-gray-500 mb-1">MNC</label>
        <input name="mncs[][mnc]" value="" class="w-full rounded border px-2 py-1">
      </div>
      <div class="col-span-3">
        <label class="block text-xs text-gray-500 mb-1">MCC-MNC</label>
        <input value="" class="w-full rounded border px-2 py-1 bg-gray-50 mccmnc" readonly>
      </div>
      <div class="col-span-3">
        <label class="block text-xs text-gray-500 mb-1">Created / Updated by</label>
        <input value="— / —" class="w-full rounded border px-2 py-1 bg-gray-50" readonly>
      </div>
      <div class="col-span-3">
        <label class="block text-xs text-gray-500 mb-1">Created / Updated at</label>
        <input value="— / —" class="w-full rounded border px-2 py-1 bg-gray-50" readonly>
      </div>
      <div class="col-span-1 text-right">
        <label class="block text-xs text-gray-500 mb-1">Remove</label>
        <input type="checkbox" class="mnc-remove">
        <input type="hidden" name="mncs[][remove]" value="0">
      </div>
    </div>
  </template>

  <script>
  (function(){
    const frm = document.getElementById('netForm');
    const quick = document.getElementById('quickMnc');
    const list = document.getElementById('mncs');
    const tpl = document.getElementById('rowTpl').content;

    // single confirm only if some rows are marked for removal
    frm.addEventListener('submit', function(e){
      const anyRemove = [...list.querySelectorAll('.mnc-remove')].some(cb => cb.checked);
      if (anyRemove) {
        if (!confirm('Remove the selected MNC(s)?')) {
          e.preventDefault();
          return false;
        }
      }
    });

    // bind remove checkboxes to set hidden field
    const syncRem = () => {
      list.querySelectorAll('.mnc-remove').forEach(cb => {
        const hid = cb.parentElement.querySelector('input[type=hidden]');
        cb.addEventListener('change', () => hid.value = cb.checked ? '1':'0');
      });
    };
    syncRem();

    // quick add by Enter
    quick.addEventListener('keydown', function(e){
      if (e.key === 'Enter') {
        e.preventDefault();
        const val = quick.value.trim();
        if (!val) return;
        const row = document.importNode(tpl, true);
        row.querySelector('input[name="mncs[][mnc]"]').value = val;
        // compute MCC-MNC readonly using Primary MCC field
        const mcc = (document.querySelector('input[name=primary_mcc]')?.value || '').trim();
        row.querySelector('.mccmnc').value = mcc + val;
        list.appendChild(row);
        syncRem();
        quick.value = '';
      }
    });

    // live MCC-MNC recompute when primary MCC changes
    const pmcc = document.querySelector('input[name=primary_mcc]');
    pmcc?.addEventListener('input', function(){
      const mcc = (pmcc.value || '').trim();
      list.querySelectorAll('div.grid').forEach(row => {
        const mnc = row.querySelector('input[name="mncs[][mnc]"]')?.value || '';
        const out = row.querySelector('.mccmnc');
        if (out) out.value = mcc + mnc;
      });
    });
  })();
  </script>
</x-app-layout>
BLADE

###############################################################################
# 6) Warm caches
###############################################################################
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "OK: Networks page fixed, ITU importer hardened, UI updated."
