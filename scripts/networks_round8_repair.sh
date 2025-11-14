#!/usr/bin/env bash
set -Eeuo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Ensure NetworkMnc model enforces mcc_mnc and casts"
cat > app/Models/NetworkMnc.php <<'PHP'
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NetworkMnc extends Model {
    protected $fillable = [
        'network_id','mcc','mnc','mcc_mnc',
        'marked_for_deletion',
        'created_by_user','updated_by_user',
        'created_by_source','updated_by_source'
    ];
    protected $casts = ['marked_for_deletion'=>'bool'];

    protected static function boot(){
        parent::boot();
        static::saving(function($m){
            $m->mcc = trim((string)$m->mcc);
            $m->mnc = trim((string)$m->mnc);
            if ($m->mcc !== '' && $m->mnc !== '') {
                $m->mcc_mnc = $m->mcc.$m->mnc;
            }
        });
    }

    public function network(){ return $this->belongsTo(\App\Models\Network::class); }
}
PHP

echo "==> Robust ImportCarriers command (tries master/main; tolerant schema; keeps Networks)"
mkdir -p app/Console/Commands
cat > app/Console/Commands/ImportCarriers.php <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Http;
use App\Models\Country;
use App\Models\CountryMcc;
use App\Models\Network;
use App\Models\NetworkMnc;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--source=itu} {--fresh}';
    protected $description = 'Import carriers (ITU/onomondo) into countries, country_mccs, network_mncs. Never deletes Networks.';

    public function handle(){
        $source = strtolower($this->option('source') ?? 'itu');

        if ($this->option('fresh')) {
            DB::statement('TRUNCATE country_mccs RESTART IDENTITY CASCADE');
            DB::statement('TRUNCATE network_mncs RESTART IDENTITY CASCADE');
            $this->info('Cleared network_mncs & country_mccs (networks kept).');
        }

        if ($source !== 'itu') {
            $this->error('Unknown source: '.$source);
            return 1;
        }

        $data = $this->fetchOnomondoJson();
        if ($data === null) {
            $this->error('Cannot fetch ITU JSON');
            return 1;
        }

        // store for debugging
        Storage::makeDirectory('carriers/itu');
        Storage::put('carriers/itu/data.json', json_encode($data, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));

        DB::transaction(function() use ($data){
            foreach ($data as $row) {
                $countryName = $row['country_name'] ?? $row['country'] ?? $row['Country'] ?? null;
                $iso2        = strtolower($row['alpha_2'] ?? $row['alpha2'] ?? '') ?: null;
                $mcc         = trim((string)($row['mcc'] ?? $row['MCC'] ?? ''));
                $mnc         = trim((string)($row['mnc'] ?? $row['MNC'] ?? ''));
                $netName     = $row['network'] ?? $row['operator'] ?? $row['brand'] ?? $row['Network'] ?? null;

                if (!$countryName || !$mcc || !$mnc || !$netName) continue;

                // ISO2 like "n/a" -> NULL to avoid varchar(2) violation
                if ($iso2 && strlen($iso2) !== 2) { $iso2 = null; }

                // Country
                $country = Country::firstOrCreate(
                    ['name' => $countryName],
                    ['iso2' => $iso2]
                );
                if ($iso2 && !$country->iso2) { $country->iso2 = $iso2; $country->save(); }

                // country_mccs
                CountryMcc::firstOrCreate(['mcc'=>$mcc], ['country_id'=>$country->id]);

                // Network (unique by country_id + lower(name))
                $normalized = mb_strtolower(trim($netName));
                $network = Network::where('country_id',$country->id)
                    ->whereRaw('lower(name) = ?', [$normalized])
                    ->first();
                if (!$network) {
                    $network = new Network();
                    $network->country_id = $country->id;
                    $network->name = trim($netName);
                    // primary_mcc is kept at network-level for edit UX; fall back to first seen
                    if (property_exists($network,'primary_mcc') || in_array('primary_mcc',$network->getFillable())) {
                        $network->primary_mcc = $mcc;
                    }
                    $network->save();
                } elseif (property_exists($network,'primary_mcc') || in_array('primary_mcc',$network->getFillable())) {
                    // keep a valid primary_mcc
                    if (!$network->primary_mcc) { $network->primary_mcc = $mcc; $network->save(); }
                }

                // Upsert NetworkMnc
                $nm = NetworkMnc::where('mcc',$mcc)->where('mnc',$mnc)->first();
                if (!$nm) {
                    $nm = new NetworkMnc();
                    $nm->mcc = $mcc;
                    $nm->mnc = $mnc;
                    $nm->network_id = $network->id;
                    $nm->created_by_source = 'ITU import';
                } else {
                    $nm->network_id = $network->id; // reattach to consolidated network
                    $nm->updated_by_source = 'ITU import';
                }
                $nm->save(); // boot() composes mcc_mnc
            }
        });

        $this->info('Import completed.');
        return 0;
    }

    private function fetchOnomondoJson(): ?array {
        $candidates = [
            'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/data.json',
            'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/data.json',
        ];

        foreach ($candidates as $url) {
            try {
                $res = Http::timeout(20)->retry(2, 500)->get($url);
                if ($res->ok()) {
                    $json = $res->json();
                    if (is_array($json)) return $json;
                }
            } catch (\Throwable $e) { /* continue */ }
        }

        // Fallback via PHP streams (some images block curl/ca)
        foreach ($candidates as $url) {
            try {
                $ctx = stream_context_create(['http'=>['timeout'=>20,'ignore_errors'=>true]]);
                $raw = @file_get_contents($url,false,$ctx);
                if ($raw && ($arr = json_decode($raw,true)) && is_array($arr)) return $arr;
            } catch (\Throwable $e) { /* continue */ }
        }
        return null;
    }
}
PHP

echo "==> Fix NetworksController@index (ordering, per-page, eager-load)"
cat > app/Http/Controllers/NetworksController.php <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Network;
use App\Models\NetworkMnc;

class NetworksController extends Controller {
    public function index(Request $r){
        $per = (int)($r->input('per', 20));
        if (!in_array($per, [20,50,100,1000])) $per = 20;

        $q = Network::query()
            ->with(['country','mncs' => function($qq){ $qq->orderBy('mnc'); }])
            ->join('countries','countries.id','=','networks.country_id');

        if ($r->filled('q'))        $q->where('networks.name','ilike','%'.$r->q.'%');
        if ($r->filled('country'))  $q->where('countries.name','ilike','%'.$r->country.'%');
        if ($r->filled('mcc'))      $q->whereHas('mncs', fn($m)=>$m->where('mcc',$r->mcc));
        if ($r->filled('mnc'))      $q->whereHas('mncs', fn($m)=>$m->where('mnc',$r->mnc));
        if ($r->filled('mcc_mnc'))  $q->whereHas('mncs', fn($m)=>$m->where('mcc_mnc','ilike','%'.$r->mcc_mnc.'%'));

        $q->orderBy('countries.name','asc')
          ->orderByRaw("(select coalesce(min(nm.mcc||nm.mnc), '')) asc");

        $networks = $q->select('networks.*')->paginate($per)->appends($r->all());

        return view('networks.index', compact('networks'));
    }

    public function create(){ return view('networks.create'); }

    public function edit(\App\Models\Network $network){
        $network->load(['country','mncs'=>fn($qq)=>$qq->orderBy('mnc')]);
        return view('networks.edit', compact('network'));
    }

    public function store(Request $r){
        $r->validate(['name'=>'required|string','country_id'=>'required|integer']);
        $n = new \App\Models\Network();
        $n->name = trim($r->name);
        $n->country_id = (int)$r->country_id;
        if ($r->filled('primary_mcc')) $n->primary_mcc = trim($r->primary_mcc);
        $n->save();
        return redirect()->route('networks.edit',$n)->with('status','Created.');
    }

    public function update(Request $r, \App\Models\Network $network){
        $network->name = trim($r->input('name',$network->name));
        if ($r->filled('primary_mcc')) $network->primary_mcc = trim($r->primary_mcc);
        $network->save();

        $mncs = $r->input('mncs', []);
        $toDelete = array_map('intval', array_keys($r->input('delete_mncs', [])));
        if ($toDelete) {
            NetworkMnc::where('network_id',$network->id)->whereIn('id',$toDelete)->delete();
        }

        $primaryMcc = (string)($network->primary_mcc ?? '');
        foreach ($mncs as $row) {
            $id  = isset($row['id']) ? (int)$row['id'] : null;
            $mnc = trim((string)($row['mnc'] ?? ''));
            if ($mnc === '') continue;

            $nm = $id
                ? NetworkMnc::where('network_id',$network->id)->where('id',$id)->first()
                : new NetworkMnc();

            if (!$nm) { $nm = new NetworkMnc(); }
            $nm->network_id = $network->id;
            $nm->mcc = $primaryMcc;
            $nm->mnc = $mnc;
            $nm->created_by_user = $nm->created_by_user ?: (auth()->user()->name ?? null);
            $nm->updated_by_user = auth()->user()->name ?? null;
            $nm->save();
        }

        return redirect()->route('networks.edit',$network)->with('status','Saved.');
    }

    public function destroy(\App\Models\Network $network){
        $network->delete();
        return back()->with('status','Deleted.');
    }
}
PHP

echo "==> Networks index view: import group on top, filters, table, pagination bottom, per-page bottom-left, Create button"
mkdir -p resources/views/networks
cat > resources/views/networks/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
    <!-- Actions row -->
    <div class="flex flex-col gap-3">
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
    </div>

    <!-- Table -->
    <div class="overflow-x-auto rounded-lg border">
      <table class="min-w-full divide-y divide-gray-200 bg-white">
        <thead class="bg-gray-50">
          <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
            <th class="px-4 py-3">Country</th>
            <th class="px-4 py-3">Network</th>
            <th class="px-4 py-3">MNCs</th>
            <th class="px-4 py-3"></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100 text-sm">
          @forelse($networks as $n)
            <tr>
              <td class="px-4 py-2">{{ $n->country?->name }}</td>
              <td class="px-4 py-2">{{ $n->name }}</td>
              <td class="px-4 py-2">
                {{ $n->mncs->pluck('mnc')->implode(', ') }}
              </td>
              <td class="px-4 py-2 text-right">
                <a href="{{ route('networks.edit', $n) }}" class="text-indigo-600 hover:underline">Edit</a>
              </td>
            </tr>
          @empty
            <tr><td colspan="4" class="px-4 py-6 text-center text-gray-500">No results.</td></tr>
          @endforelse
        </tbody>
      </table>
    </div>

    <!-- Footer: per-page (left) + links (right) -->
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
      <div class="text-sm">
        {{ $networks->onEachSide(1)->links() }}
      </div>
    </div>
  </div>
</x-app-layout>
BLADE

echo "==> Networks edit view: real MNC rows, readonly MCC-MNC, quick add by Enter, single confirm on Save (only if deletions checked)"
cat > resources/views/networks/edit.blade.php <<'BLADE'
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
          <input name="primary_mcc" value="{{ old('primary_mcc', $network->primary_mcc) }}" class="mt-1 w-full rounded border px-3 py-2">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Created / Updated by</label>
          <input value="{{ $network->updated_by_user ?? $network->created_by_user ?? '—' }}" class="mt-1 w-full rounded border px-3 py-2 bg-gray-50" readonly>
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
                <input value="{{ ($network->primary_mcc ?? '') . ($row['mnc'] ?? '') }}" class="w-full rounded border px-2 py-1 bg-gray-50" readonly>
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
      if (anyDelete && !confirm('Remove selected MNCs?')) {
        e.preventDefault();
      }
    });

    const tmpl = document.getElementById('mnc-template').innerHTML;
    const rows = document.getElementById('mnc-rows');
    const quick = document.getElementById('quick-mnc');
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
        const mcc = document.querySelector('input[name="primary_mcc"]')?.value || '';
        node.querySelector('input[readonly]').value = mcc + val;
        rows.appendChild(node);
        quick.value = '';
      }
    });

    rows.addEventListener('input', function(e){
      if (e.target.name && e.target.name.endsWith('[mnc]')) {
        const wrapper = e.target.closest('.grid');
        const mcc = document.querySelector('input[name="primary_mcc"]')?.value || '';
        wrapper.querySelector('input[readonly]').value = mcc + e.target.value;
      }
    });
    const mccInput = document.querySelector('input[name="primary_mcc"]');
    if (mccInput) {
      mccInput.addEventListener('input', function(){
        document.querySelectorAll('#mnc-rows .grid').forEach(function(row){
          const mncVal = row.querySelector('input[name$="[mnc]"]').value || '';
          row.querySelector('input[readonly]').value = mccInput.value + mncVal;
        });
      });
    }
  })();
  </script>
</x-app-layout>
BLADE

echo "==> Warm caches"
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "OK: importer, controller, views updated."
