#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

### 1) CountriesController — robust index()/edit()
F=app/Http/Controllers/CountriesController.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Country;

class CountriesController extends Controller
{
    public function index(Request $r)
    {
        $per = max(1, min(1000, (int) $r->integer('per', 20)));
        $countries = Country::with('mccs')
            ->orderBy('name','asc')
            ->paginate($per);
        return view('countries.index', compact('countries'));
    }

    public function edit(Country $country)
    {
        $country->load('mccs');
        $mccs = $country->mccs; // Pass the Collection; the view will pluck->implode
        return view('countries.edit', compact('country','mccs'));
    }
}
PHP

### 2) NetworksController — stable list/create/edit/update/destroy
F=app/Http/Controllers/NetworksController.php
b "$F"
cat > "$F" <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Network;
use App\Models\NetworkMnc;

class NetworksController extends Controller
{
    public function index(Request $r)
    {
        $per = (int) $r->input('per', 20);
        if (!in_array($per, [20,50,100,1000])) $per = 20;

        $q = Network::query()
            ->with(['country','mncs' => fn($qq) => $qq->orderBy('mnc')])
            ->join('countries','countries.id','=','networks.country_id');

        if ($r->filled('q'))        $q->where('networks.name','ilike','%'.$r->q.'%');
        if ($r->filled('country'))  $q->where('countries.name','ilike','%'.$r->country.'%');
        if ($r->filled('mcc'))      $q->whereHas('mncs', fn($m)=>$m->where('mcc',$r->mcc));
        if ($r->filled('mnc'))      $q->whereHas('mncs', fn($m)=>$m->where('mnc',$r->mnc));
        if ($r->filled('mcc_mnc'))  $q->whereHas('mncs', fn($m)=>$m->where('mcc_mnc','ilike','%'.$r->mcc_mnc.'%'));

        $q->orderBy('countries.name','asc')
          ->orderByRaw("(select coalesce(min(nm.mcc::text || nm.mnc::text), '') from network_mncs nm where nm.network_id = networks.id) asc");

        $networks = $q->select('networks.*')->paginate($per)->appends($r->all());
        return view('networks.index', compact('networks'));
    }

    public function create()
    {
        $countries = \App\Models\Country::orderBy('name')->get();
        return view('networks.create', compact('countries'));
    }

    public function edit(Network $network)
    {
        $network->load(['mncs','country.mccs']);
        return view('networks.edit', compact('network'));
    }

    public function store(Request $r)
    {
        $r->validate([
            'name' => 'required|string',
            'country_id' => 'required|integer|exists:countries,id',
        ]);
        $n = new Network();
        $n->name = trim($r->name);
        $n->country_id = (int) $r->country_id;
        $n->save();
        return redirect()->route('networks.edit',$n)->with('status','Created.');
    }

    public function update(Request $r, Network $network)
    {
        $network->name = trim($r->input('name',$network->name));
        $network->save();

        $mncs = $r->input('mncs', []);
        $toDelete = array_keys($r->input('delete_mncs', []));
        if (!empty($toDelete)) {
            NetworkMnc::where('network_id',$network->id)->whereIn('id', array_map('intval',$toDelete))->delete();
        }

        // Primary MCC from country->mccs->first()->mcc (or '')
        $primaryMcc = (string) optional(optional($network->country)->mccs->first())->mcc ?? '';

        foreach ($mncs as $row) {
            $id  = isset($row['id']) ? (int)$row['id'] : null;
            $mnc = isset($row['mnc']) ? trim((string)$row['mnc']) : '';
            if ($mnc === '') continue;

            $nm = $id
                ? NetworkMnc::where('network_id',$network->id)->where('id',$id)->first()
                : new NetworkMnc();

            if (!$nm) $nm = new NetworkMnc();
            $nm->network_id = $network->id;
            $nm->mcc = $primaryMcc; // Model will still try to infer if empty
            $nm->mnc = $mnc;
            $nm->save(); // computes mcc_mnc
        }

        return redirect()->route('networks.edit',$network)->with('status','Saved.');
    }

    public function destroy(Network $network)
    {
        $network->delete();
        return back()->with('status','Deleted.');
    }
}
PHP

### 3) NetworkMnc model — compute mcc_mnc + fallback MCC
F=app/Models/NetworkMnc.php
b "$F"
cat > "$F" <<'PHP'
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMnc extends Model
{
    protected $fillable = ['network_id','mcc','mnc','mcc_mnc','created_by_source','updated_by_source'];
    public $timestamps = true;

    public function network(): BelongsTo { return $this->belongsTo(Network::class); }

    protected static function booted()
    {
        static::saving(function (self $m) {
            if (empty($m->mcc)) {
                if ($m->relationLoaded('network') && $m->network) {
                    $m->mcc = (string) optional(optional($m->network->country)->mccs->first())->mcc ?? $m->mcc;
                } elseif ($m->network_id) {
                    $net = Network::with('country.mccs')->find($m->network_id);
                    if ($net) $m->mcc = (string) optional(optional($net->country)->mccs->first())->mcc ?? $m->mcc;
                }
            }
            $mcc = preg_replace('/\D+/','', (string) $m->mcc);
            $mnc = preg_replace('/\D+/','', (string) $m->mnc);
            $m->mcc = $mcc;
            $m->mnc = $mnc;
            $m->mcc_mnc = ($mcc !== '' && $mnc !== '') ? ($mcc.$mnc) : null;
        });
    }
}
PHP

### 4) Countries edit view — stop imploding a Collection
F=resources/views/countries/edit.blade.php
if [ -f "$F" ]; then
  b "$F"
  # Replace any implode($mccs, ...) with safe pluck->toArray()
  perl -0777 -pe "s/implode\(([^,]+),\s*\$mccs\s*\)/implode(\$1, \$mccs->pluck('mcc')->toArray())/g" -i "$F" || true
  # Also handle implode(\$mccs, ', ') style
  perl -0777 -pe "s/implode\(\s*\$mccs\s*,\s*([^)]+)\)/implode(\$mccs->pluck('mcc')->toArray(), \$1)/g" -i "$F" || true
fi

### 5) Networks list view — Actions restored, footer per-page on left
F=resources/views/networks/index.blade.php
b "$F"
cat > "$F" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
    <!-- Actions row -->
    <div class="flex items-center justify-between">
      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-3">
        @csrf
        <button type="submit" class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Fresh Import</button>
        <label class="text-sm text-gray-600">Import Source</label>
        <select name="source" class="rounded border px-2 py-1">
          <option value="itu" {{ request('source','itu')==='itu' ? 'selected' : '' }}>ITU</option>
        </select>
        <input type="hidden" name="fresh" value="1">
      </form>

      <a href="{{ route('networks.create') }}" class="inline-flex items-center rounded-md bg-gray-800 px-3 py-2 text-white hover:bg-gray-900">Create Network</a>
    </div>

    <!-- Filters -->
    <form method="GET" action="{{ route('networks.index') }}" class="flex flex-wrap items-center gap-2">
      <input name="q" value="{{ request('q') }}" placeholder="Search network name…" class="rounded border px-3 py-2">
      <input name="country" value="{{ request('country') }}" placeholder="Country…" class="rounded border px-3 py-2">
      <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC…" class="rounded border px-3 py-2 w-24">
      <input name="mnc" value="{{ request('mnc') }}" placeholder="MNC…" class="rounded border px-3 py-2 w-24">
      <input name="mcc_mnc" value="{{ request('mcc_mnc') }}" placeholder="MCC-MNC…" class="rounded border px-3 py-2 w-36">
      <button class="rounded border px-4 py-2 bg-white hover:bg-gray-50">Filter</button>
    </form>

    <!-- Table -->
    <div class="overflow-x-auto rounded-lg border">
      <table class="min-w-full divide-y divide-gray-200 bg-white">
        <thead class="bg-gray-50">
          <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
            <th class="px-4 py-3">Country</th>
            <th class="px-4 py-3">Network</th>
            <th class="px-4 py-3">MNCs</th>
            <th class="px-4 py-3">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100 text-sm">
          @forelse($networks as $n)
            <tr>
              <td class="px-4 py-2">{{ $n->country?->name }}</td>
              <td class="px-4 py-2">{{ $n->name }}</td>
              <td class="px-4 py-2">{{ $n->mncs->pluck('mnc')->implode(', ') }}</td>
              <td class="px-4 py-2 text-right">
                <a href="{{ route('networks.edit', $n) }}" class="text-indigo-600 hover:underline mr-3">Edit</a>
                <form action="{{ route('networks.destroy', $n) }}" method="POST" class="inline">
                  @csrf @method('DELETE')
                  <button type="submit" onclick="return confirm('Delete this network?')" class="text-red-600 hover:underline">Delete</button>
                </form>
              </td>
            </tr>
          @empty
            <tr><td colspan="4" class="px-4 py-6 text-center text-gray-500">No results.</td></tr>
          @endforelse
        </tbody>
      </table>
    </div>

    <!-- Footer -->
    <div class="flex items-center justify-between">
      <form method="GET" action="{{ route('networks.index') }}" class="flex items-center gap-2 text-sm text-gray-600">
        @foreach(request()->except('per','page') as $k=>$v)
          <input type="hidden" name="{{ $k }}" value="{{ $v }}">
        @endforeach
        <div>
          @if($networks->total())
            Showing {{ $networks->firstItem() }}–{{ $networks->lastItem() }} of {{ $networks->total() }} results
          @else
            Showing 0 of 0 results
          @endif
        </div>
        <select name="per" class="rounded border px-2 py-1" onchange="this.form.submit()">
          @foreach([20,50,100,1000] as $opt)
            <option value="{{ $opt }}" {{ $networks->perPage()===$opt ? 'selected' : '' }}>{{ $opt }}</option>
          @endforeach
        </select>
      </form>
      <div class="text-sm">{{ $networks->onEachSide(1)->links() }}</div>
    </div>
  </div>
</x-app-layout>
BLADE

### 6) Networks create/edit views — safe Primary MCC + single-confirm delete
F=resources/views/networks/create.blade.php
b "$F"
cat > "$F" <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Create Network</h2></x-slot>
  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.store') }}" class="space-y-6 bg-white p-4 rounded-lg border">
      @csrf
      <div>
        <label class="block text-sm font-medium text-gray-700">Name</label>
        <input name="name" value="{{ old('name') }}" class="mt-1 w-full rounded border px-3 py-2">
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700">Country</label>
        <select name="country_id" class="mt-1 w-full rounded border px-3 py-2">
          @foreach(\App\Models\Country::orderBy('name')->get() as $c)
            <option value="{{ $c->id }}">{{ $c->name }}</option>
          @endforeach
        </select>
      </div>
      <div class="flex items-center gap-3">
        <button class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Create</button>
        <a href="{{ route('networks.index') }}" class="rounded border px-4 py-2 bg-white hover:bg-gray-50">Back</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

F=resources/views/networks/edit.blade.php
b "$F"
cat > "$F" <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2></x-slot>

  <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded bg-green-50 text-green-700 px-4 py-2">{{ session('status') }}</div>
    @endif

    <form method="POST" action="{{ route('networks.update', $network) }}" id="net-form" class="space-y-6">
      @csrf @method('PUT')

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 bg-white rounded-lg p-4 border">
        <div>
          <label class="block text-sm font-medium text-gray-700">Name</label>
          <input name="name" value="{{ old('name', $network->name) }}" class="mt-1 w-full rounded border px-3 py-2">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Country</label>
          <input value="{{ $network->country?->name }}" class="mt-1 w-full rounded border px-3 py-2 bg-gray-50" readonly>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Primary MCC</label>
          @php $primaryMcc = $network->country?->mccs?->pluck('mcc')->first() ?? ''; @endphp
          <input id="primary-mcc-val" value="{{ $primaryMcc }}" class="mt-1 w-full rounded border px-3 py-2 bg-gray-50" readonly>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Created / Updated by</label>
          <input value="—" class="mt-1 w-full rounded border px-3 py-2 bg-gray-50" readonly>
        </div>
      </div>

      <div class="bg-white rounded-lg p-4 border">
        <div class="flex items-center justify-between mb-3">
          <h3 class="font-semibold">MNCs</h3>
          <input id="quick-mnc" placeholder="Type MNC and press Enter" class="rounded border px-3 py-2 w-56">
        </div>

        <div id="mnc-rows" class="space-y-2">
          @php $rows = old('mncs', $network->mncs->map(fn($m)=>['id'=>$m->id,'mnc'=>$m->mnc])->toArray()); @endphp
          @foreach($rows as $i => $row)
            <div class="grid grid-cols-12 gap-2 items-center border rounded p-2">
              <input type="hidden" name="mncs[{{ $i }}][id]" value="{{ $row['id'] ?? '' }}">
              <div class="col-span-4">
                <label class="text-xs text-gray-600">MNC</label>
                <input name="mncs[{{ $i }}][mnc]" value="{{ $row['mnc'] ?? '' }}" class="w-full rounded border px-2 py-1">
              </div>
              <div class="col-span-6">
                <label class="text-xs text-gray-600">MCC-MNC (readonly)</label>
                <input value="{{ ($primaryMcc) . ($row['mnc'] ?? '') }}" class="w-full rounded border px-2 py-1 bg-gray-50" readonly>
              </div>
              <div class="col-span-2 flex items-end justify-end">
                @if(!empty($row['id']))
                  <label class="inline-flex items-center gap-2 text-sm">
                    <input type="checkbox" class="rm-mnc" name="delete_mncs[{{ $row['id'] }}]" value="{{ $row['id'] }}">
                    <span>Remove</span>
                  </label>
                @endif
              </div>
            </div>
          @endforeach
        </div>
      </div>

      <div class="flex items-center gap-3">
        <button class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded border px-4 py-2 bg-white hover:bg-gray-50">Back</a>
      </div>
    </form>
  </div>

  <template id="mnc-template">
    <div class="grid grid-cols-12 gap-2 items-center border rounded p-2">
      <input type="hidden" name="TBD[id]" value="">
      <div class="col-span-4">
        <label class="text-xs text-gray-600">MNC</label>
        <input name="TBD[mnc]" value="" class="w-full rounded border px-2 py-1">
      </div>
      <div class="col-span-6">
        <label class="text-xs text-gray-600">MCC-MNC (readonly)</label>
        <input value="" class="w-full rounded border px-2 py-1 bg-gray-50" readonly>
      </div>
      <div class="col-span-2"></div>
    </div>
  </template>

  <script>
  (function(){
    const form = document.getElementById('net-form');
    form.addEventListener('submit', function(e){
      const anyDelete = !!document.querySelector('.rm-mnc:checked');
      if (anyDelete && !confirm('Remove selected MNCs?')) e.preventDefault();
    });

    const tmpl = document.getElementById('mnc-template').innerHTML;
    const rows = document.getElementById('mnc-rows');
    const quick = document.getElementById('quick-mnc');
    const mccInput = document.getElementById('primary-mcc-val');
    const currentMcc = () => (mccInput?.value || '');

    quick.addEventListener('keydown', function(e){
      if (e.key === 'Enter') {
        e.preventDefault();
        const val = quick.value.trim(); if (!val) return;
        const idx = rows.querySelectorAll('.grid').length;
        const html = tmpl.replaceAll('TBD', 'mncs['+idx+']');
        const div = document.createElement('div'); div.innerHTML = html;
        const node = div.firstElementChild;
        node.querySelector('input[name^="mncs"][name$="[mnc]"]').value = val;
        node.querySelector('input[readonly]').value = currentMcc() + val;
        rows.appendChild(node); quick.value = '';
      }
    });

    rows.addEventListener('input', function(e){
      if (e.target.name && e.target.name.endsWith('[mnc]')) {
        const wrap = e.target.closest('.grid');
        wrap.querySelector('input[readonly]').value = currentMcc() + e.target.value;
      }
    });
  })();
  </script>
</x-app-layout>
BLADE

### 7) Import — controller + artisan command (multi-source, non-destructive to Networks)
# Route (add if missing)
F=routes/web.php
b "$F"
grep -q "carriers.import" "$F" || cat >> "$F" <<'PHP'
use App\Http\Controllers\CarriersImportController;
Route::post('/carriers/import', [CarriersImportController::class,'run'])->name('carriers.import')->middleware(['web','auth']);
PHP

# Controller
F=app/Http/Controllers/CarriersImportController.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use App\Models\Country;
use App\Models\Network;
use App\Models\NetworkMnc;

class CarriersImportController extends Controller
{
    public function run(Request $r)
    {
        $source = strtolower($r->input('source','itu'));
        $fresh  = (bool)$r->boolean('fresh', false);

        [$ok,$msg] = self::importNow($source, $fresh);
        return back()->with('status', $ok ? "Import finished (code 0). $msg" : "Import finished (code 1). $msg");
    }

    /** Import implementation shared with console command */
    public static function importNow(string $source, bool $fresh): array
    {
        if ($fresh) {
            DB::table('network_mncs')->truncate();
            DB::table('country_mccs')->truncate();
        }

        // Try multiple public datasets (best-effort). 
        // [Unverified] Endpoints may change; we fall back in order.
        $urls = [
            'itu' => [
                'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
            ],
            'mccmnc' => [
                'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
            ],
        ];
        $pool = $urls[$source] ?? $urls['mccmnc'];

        $data = null; $used = null; $err = [];
        foreach ($pool as $u) {
            try {
                $res = Http::timeout(25)->get($u);
                if ($res->ok()) { $data = $res->json(); $used = $u; break; }
                $err[] = "HTTP ".($res->status())." on $u";
            } catch (\Throwable $e) { $err[] = $e->getMessage(); }
        }
        if (!$data || !is_array($data)) {
            return [false, "Cannot fetch MCC/MNC dataset (".implode(' | ',$err).")"];
        }

        // dataset expected: array of rows with keys like mcc,mnc,country,brand,operator,iso
        $rows = $data['records'] ?? $data; // some repos use top-level array
        if (!is_array($rows)) return [false, "Unexpected dataset format"];

        $count = 0; $createdCountries=0; $createdNetworks=0; $createdMncs=0;

        DB::transaction(function() use (&$rows,&$count,&$createdCountries,&$createdNetworks,&$createdMncs){
            foreach ($rows as $row) {
                $mcc = trim((string)($row['mcc'] ?? ''));
                $mnc = trim((string)($row['mnc'] ?? ''));
                if ($mcc === '' || $mnc === '') continue;

                $countryName = trim((string)($row['country'] ?? ($row['country_name'] ?? 'Unknown')));
                $iso2 = strtolower((string)($row['iso'] ?? ($row['iso2'] ?? '')));
                $brand = trim((string)($row['brand'] ?? ($row['operator'] ?? 'Unknown')));

                $country = Country::firstOrCreate(
                    ['name'=>$countryName],
                    ['iso2'=>$iso2]
                );
                if ($country->wasRecentlyCreated) $createdCountries++;

                $network = Network::firstOrCreate(
                    ['name'=>$brand, 'country_id'=>$country->id],
                    []
                );
                if ($network->wasRecentlyCreated) $createdNetworks++;

                $exists = NetworkMnc::where('network_id',$network->id)
                    ->where('mcc',$mcc)->where('mnc',$mnc)->exists();
                if (!$exists) {
                    NetworkMnc::create(['network_id'=>$network->id,'mcc'=>$mcc,'mnc'=>$mnc]);
                    $createdMncs++;
                }

                $count++;
            }
        });

        return [true, "Source used: ".($used ?? 'unknown')." — processed $count rows; created: countries=$createdCountries, networks=$createdNetworks, mncs=$createdMncs"];
    }
}
PHP

# Console command
F=app/Console/Commands/CarriersImport.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Http\Controllers\CarriersImportController;

class CarriersImport extends Command
{
    protected $signature = 'carriers:import {--source=itu} {--fresh}';
    protected $description = 'Import carriers/MNCs from public dataset (best-effort).';

    public function handle()
    {
        $source = strtolower($this->option('source'));
        $fresh  = (bool) $this->option('fresh');

        [$ok,$msg] = CarriersImportController::importNow($source, $fresh);
        $this->line($msg);
        return $ok ? self::SUCCESS : self::FAILURE;
    }
}
PHP

# Ensure command is auto-discovered (Laravel 12 does this). Warm caches.
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "Round 12: controllers, views, model, import (controller+artisan) applied."
