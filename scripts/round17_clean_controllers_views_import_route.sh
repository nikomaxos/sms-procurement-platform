#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> 1) Service: App\\Services\\CarrierImportService (idempotent)"
F=app/Services/CarrierImportService.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use App\Models\Country;
use App\Models\Network;

class CarrierImportService {
    /**
     * @return array{ok:bool,msg:string,createdCountries:int,createdNetworks:int,createdMncs:int}
     */
    public function import(string $source, bool $fresh): array {
        $createdCountries=0; $createdNetworks=0; $createdMncs=0;

        if ($fresh) {
            DB::table('network_mncs')->truncate();
            DB::table('country_mccs')->truncate();
        }

        $urls = [
            'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
        ];
        $rows = [];
        foreach ($urls as $url) {
            try {
                $res = Http::timeout(30)->get($url);
                if ($res->successful() && is_array($res->json())) {
                    $rows = array_merge($rows, $res->json());
                }
            } catch (\Throwable $e) {}
        }
        if (!$rows) return ['ok'=>false,'msg'=>'No data fetched','createdCountries'=>0,'createdNetworks'=>0,'createdMncs'=>0];

        DB::transaction(function () use ($rows, &$createdCountries, &$createdNetworks, &$createdMncs) {
            foreach ($rows as $r) {
                $mcc = (string)($r['mcc'] ?? $r['MCC'] ?? '');
                $mnc = (string)($r['mnc'] ?? $r['MNC'] ?? '');
                $cname = trim((string)($r['country'] ?? $r['country_name'] ?? $r['countryName'] ?? ''));
                $iso2  = $r['iso'] ?? $r['iso2'] ?? $r['country_code'] ?? null;
                $netName = trim((string)($r['brand'] ?? $r['operator'] ?? $r['network'] ?? ''));
                if ($mcc==='' || $mnc==='' || $cname==='' || $netName==='') continue;

                $country = Country::firstOrCreate(
                    ['name'=>$cname],
                    ['iso2'=> is_string($iso2) ? strtolower(substr($iso2,0,2)) : null]
                );
                if ($country->wasRecentlyCreated) $createdCountries++;

                // country_mccs
                if (!DB::table('country_mccs')->where(['country_id'=>$country->id,'mcc'=>$mcc])->exists()) {
                    DB::table('country_mccs')->insert(['country_id'=>$country->id,'mcc'=>$mcc,'created_at'=>now(),'updated_at'=>now()]);
                }

                // networks
                $network = Network::firstOrCreate(['name'=>$netName,'country_id'=>$country->id],[]);
                if ($network->wasRecentlyCreated) $createdNetworks++;

                // network_mncs
                if (!DB::table('network_mncs')->where(['network_id'=>$network->id,'mcc'=>$mcc,'mnc'=>$mnc])->exists()) {
                    DB::table('network_mncs')->insert([
                        'network_id'=>$network->id,
                        'mcc'=>$mcc,
                        'mnc'=>$mnc,
                        'mcc_mnc'=>$mcc.$mnc,
                        'created_at'=>now(),'updated_at'=>now(),
                    ]);
                    $createdMncs++;
                }
            }
        });

        return ['ok'=>true,'msg'=>'Import complete','createdCountries'=>$createdCountries,'createdNetworks'=>$createdNetworks,'createdMncs'=>$createdMncs];
    }
}
PHP

echo "==> 2) GET+POST routes for importer + small GET view"
b routes/web.php
awk 'BEGIN{p=1} {print} END{
  print "";
  print "use App\\Http\\Controllers\\CarriersImportController;";
  print "Route::get(\"/carriers/import\", function(){ return view(\"carriers.import\"); })->name(\"carriers.import.form\");";
  print "Route::post(\"/carriers/import\", [CarriersImportController::class, \"run\")->name(\"carriers.import\");";
}' routes/web.php > routes/web.php.tmp && mv routes/web.php.tmp routes/web.php

V=resources/views/carriers/import.blade.php
mkdir -p "$(dirname "$V")"
cat > "$V" <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Import Carriers (ITU)</h2></x-slot>
  <div class="py-6 max-w-xl mx-auto px-4 sm:px-6 lg:px-8">
    @if ($errors->any())
      <div class="mb-4 rounded bg-red-50 text-red-700 px-4 py-2">{{ $errors->first() }}</div>
    @endif
    @if (session('status'))
      <div class="mb-4 rounded bg-green-50 text-green-700 px-4 py-2">{{ session('status') }}</div>
    @endif
    <form method="POST" action="{{ route('carriers.import') }}" class="space-y-3 bg-white p-4 border rounded">
      @csrf
      <label class="block text-sm text-gray-700">Source</label>
      <select name="source" class="rounded border px-3 py-2">
        <option value="itu" selected>ITU JSON (github raw)</option>
      </select>
      <label class="inline-flex items-center gap-2"><input type="checkbox" name="fresh" value="1"> <span>Fresh (truncate links)</span></label>
      <div class="flex items-center gap-3">
        <button class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Run Import</button>
        <a href="{{ route('networks.index') }}" class="rounded border px-4 py-2 bg-white hover:bg-gray-50">Back</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

echo "==> 3) CarriersImportController"
F=app/Http/Controllers/CarriersImportController.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\CarrierImportService;

class CarriersImportController extends Controller
{
    public function run(Request $r, CarrierImportService $svc)
    {
        $source = (string) $r->input('source','itu');
        $fresh  = (bool) $r->boolean('fresh', false);
        $out = $svc->import($source, $fresh);
        if (!$out['ok']) {
            return back()->withErrors(['import'=>$out['msg']]);
        }
        return back()->with('status', sprintf(
            'Import OK: %s (countries +%d, networks +%d, mncs +%d)',
            $out['msg'], $out['createdCountries'], $out['createdNetworks'], $out['createdMncs']
        ));
    }
}
PHP

echo "==> 4) CountriesController (overwrite clean)"
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
        $per = max(1, min(1000, (int)$r->integer('per', 20)));
        $countries = Country::with('mccs')->orderBy('name','asc')->paginate($per);
        return view('countries.index', compact('countries'));
    }

    public function edit(Country $country)
    {
        $country->load('mccs');
        $mccs = $country->mccs->pluck('mcc')->all(); // array for implode
        return view('countries.edit', compact('country','mccs'));
    }
}
PHP

echo "==> 5) NetworksController (overwrite clean; fixes syntax error + null-safety)"
F=app/Http/Controllers/NetworksController.php
b "$F"; mkdir -p "$(dirname "$F")"
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
        if (!in_array($per,[20,50,100,1000])) $per = 20;

        $q = Network::query()->with(['country','mncs'=>fn($qq)=>$qq->orderBy('mnc')]);

        if ($r->filled('q'))       $q->where('name','ilike','%'.$r->q.'%');
        if ($r->filled('country')) $q->whereHas('country', fn($c)=>$c->where('name','ilike','%'.$r->country.'%'));
        if ($r->filled('mcc'))     $q->whereHas('mncs', fn($m)=>$m->where('mcc',$r->mcc));
        if ($r->filled('mnc'))     $q->whereHas('mncs', fn($m)=>$m->where('mnc',$r->mnc));
        if ($r->filled('mcc_mnc')) $q->whereHas('mncs', fn($m)=>$m->where('mcc_mnc','ilike','%'.$r->mcc_mnc.'%'));

        $networks = $q->orderBy('name','asc')->paginate($per)->appends($r->all());
        return view('networks.index', compact('networks'));
    }

    public function create()
    {
        $network = new Network();
        return view('networks.create', compact('network'));
    }

    public function edit(Network $network)
    {
        $network->load(['mncs','country.mccs']);
        $primaryMcc = $network->mncs->pluck('mcc')->filter()->first()
            ?? optional($network->country?->mccs->first())->mcc
            ?? '';
        return view('networks.edit', compact('network','primaryMcc'));
    }

    public function store(Request $r)
    {
        $data = $r->validate([
            'name'=>'required|string',
            'country_id'=>'required|integer'
        ]);
        $n = new Network($data);
        $n->save();
        return redirect()->route('networks.edit',$n)->with('status','Created.');
    }

    public function update(Request $r, Network $network)
    {
        $network->name = trim((string)$r->input('name',$network->name));
        $network->save();

        $network->load(['mncs','country.mccs']);
        $primaryMcc = $network->mncs->pluck('mcc')->filter()->first()
            ?? optional($network->country?->mccs->first())->mcc
            ?? '';

        $mncs = (array) $r->input('mncs', []);
        $toDelete = array_map('intval', array_keys((array)$r->input('delete_mncs', [])));
        if ($toDelete) {
            NetworkMnc::where('network_id',$network->id)->whereIn('id',$toDelete)->delete();
        }

        foreach ($mncs as $row) {
            $id  = isset($row['id']) ? (int)$row['id'] : null;
            $mnc = trim((string)($row['mnc'] ?? ''));
            if ($mnc==='') continue;

            $nm = $id
                ? NetworkMnc::where('network_id',$network->id)->where('id',$id)->first()
                : new NetworkMnc();

            if (!$nm) $nm = new NetworkMnc();
            $nm->network_id = $network->id;
            $nm->mcc = (string)$primaryMcc;
            $nm->mnc = $mnc;
            $nm->mcc_mnc = ((string)$primaryMcc).$mnc;
            $nm->save();
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

echo "==> 6) networks/edit.blade.php — safe Primary MCC (readonly) and MCC-MNC display"
V=resources/views/networks/edit.blade.php
b "$V"
cat > "$V" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2>
  </x-slot>

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
          <input value="{{ $primaryMcc ?? '' }}" class="mt-1 w-full rounded border px-3 py-2 bg-gray-50" readonly>
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
                <input value="{{ ($primaryMcc ?? '') . ($row['mnc'] ?? '') }}" class="w-full rounded border px-2 py-1 bg-gray-50" readonly>
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
    const rows = document.getElementById('mnc-rows');
    const quick = document.getElementById('quick-mnc');
    const tmpl = document.getElementById('mnc-template').innerHTML;
    const primaryMcc = "{{ $primaryMcc ?? '' }}";

    document.getElementById('net-form').addEventListener('submit', function(e){
      const anyDelete = !!document.querySelector('.rm-mnc:checked');
      if (anyDelete && !confirm('Remove selected MNCs?')) e.preventDefault();
    });

    quick.addEventListener('keydown', function(e){
      if (e.key === 'Enter') {
        e.preventDefault();
        const val = quick.value.trim();
        if (!val) return;
        const idx = rows.querySelectorAll('.grid').length;
        const html = tmpl.replaceAll('TBD', 'mncs['+idx+']');
        const div = document.createElement('div');
        div.innerHTML = html;
        const node = div.firstElementChild;
        node.querySelector('input[name^="mncs"][name$="[mnc]"]').value = val;
        node.querySelector('input[readonly]').value = primaryMcc + val;
        rows.appendChild(node);
        quick.value = '';
      }
    });

    rows.addEventListener('input', function(e){
      if (e.target.name && e.target.name.endsWith('[mnc]')) {
        const wrapper = e.target.closest('.grid');
        wrapper.querySelector('input[readonly]').value = primaryMcc + e.target.value;
      }
    });
  })();
  </script>
</x-app-layout>
BLADE

echo "==> 7) networks/create.blade.php — simple safe form"
V=resources/views/networks/create.blade.php
b "$V"
cat > "$V" <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Create Network</h2></x-slot>
  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.store') }}" class="space-y-4 bg-white p-4 rounded border">
      @csrf
      <div>
        <label class="block text-sm font-medium text-gray-700">Name</label>
        <input name="name" value="{{ old('name') }}" class="mt-1 w-full rounded border px-3 py-2">
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700">Country ID</label>
        <input name="country_id" value="{{ old('country_id') }}" class="mt-1 w-full rounded border px-3 py-2">
      </div>
      <div class="flex items-center gap-3">
        <button class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded border px-4 py-2 bg-white hover:bg-gray-50">Back</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

echo "==> 8) networks/index.blade.php — ensure Actions col exists (Edit/Delete)"
V=resources/views/networks/index.blade.php
if [ -f "$V" ]; then
  b "$V"
  perl -0777 -pe 's|<thead class="bg-gray-50">.*?</thead>|<thead class="bg-gray-50">
  <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
    <th class="px-4 py-3">Country</th>
    <th class="px-4 py-3">Network</th>
    <th class="px-4 py-3">MNCs</th>
    <th class="px-4 py-3">Actions</th>
  </tr>
</thead>|s' -i "$V"
  perl -0777 -pe 's|<td class="px-4 py-2 text-right">.*?</td>|<td class="px-4 py-2 text-right">
  <a href="{{ route('"'"'networks.edit'"'"', $n) }}" class="text-indigo-600 hover:underline mr-3">Edit</a>
  <form action="{{ route('"'"'networks.destroy'"'"', $n) }}" method="POST" class="inline">
    @csrf @method('"'"'DELETE'"'"')
    <button type="submit" onclick="return confirm('"'"'Delete this network?'"'"')" class="text-red-600 hover:underline">Delete</button>
  </form>
</td>|s' -i "$V"
fi

echo "==> 9) Autoload + cache warm"
$DC exec -T app sh -lc '
  composer dump-autoload -o
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'
echo "Done: Round 17 applied."
