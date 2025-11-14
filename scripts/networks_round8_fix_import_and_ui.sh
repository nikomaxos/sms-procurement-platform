#!/usr/bin/env bash
set -Eeuo pipefail

if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> 1) Ensure NetworkMnc model computes mcc_mnc"
cat > app/Models/NetworkMnc.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NetworkMnc extends Model {
    protected $fillable = ['network_id','mcc','mnc','mcc_mnc','created_by','updated_by','created_by_source','updated_by_source'];
    protected static function booted(){
        static::saving(function($m){
            $mcc = trim((string)$m->mcc);
            $mnc = trim((string)$m->mnc);
            $m->mcc_mnc = $m->mcc_mnc ?: ($mcc.$mnc);
        });
    }
    public function network(){ return $this->belongsTo(Network::class); }
}
PHP

echo "==> 2) NetworksController (index sorting, filters, update with MNC rows)"
cat > app/Http/Controllers/NetworksController.php <<'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Network;
use App\Models\NetworkMnc;
use App\Models\Country;

class NetworksController extends Controller {

    public function index(Request $r){
        $per = (int)($r->query('per', 20));
        if (!in_array($per, [20,50,100,1000], true)) $per = 20;

        $q = Network::query()
            ->select('networks.*')
            ->with(['country','mncs'])
            ->join('countries','countries.id','=','networks.country_id');

        // Free-text q on network name
        if ($r->filled('q')) {
            $q->where('networks.name','ilike','%'.$r->q.'%');
        }

        // Country name filter
        if ($r->filled('country')) {
            $q->where('countries.name','ilike','%'.$r->country.'%');
        }

        // Filters through related MNCs
        if ($r->filled('mcc')) {
            $q->whereExists(function($sub) use ($r){
                $sub->from('network_mncs as nm')
                    ->whereColumn('nm.network_id','networks.id')
                    ->where('nm.mcc',$r->mcc);
            });
        }
        if ($r->filled('mnc')) {
            $q->whereExists(function($sub) use ($r){
                $sub->from('network_mncs as nm')
                    ->whereColumn('nm.network_id','networks.id')
                    ->where('nm.mnc',$r->mnc);
            });
        }
        if ($r->filled('mcc_mnc')) {
            $q->whereExists(function($sub) use ($r){
                $sub->from('network_mncs as nm')
                    ->whereColumn('nm.network_id','networks.id')
                    ->where('nm.mcc_mnc','ilike','%'.$r->mcc_mnc.'%');
            });
        }

        // Sort: Country asc, then min(mcc||mnc) asc
        $q->orderBy('countries.name','asc')
          ->orderByRaw("(select coalesce(min(nm.mcc||nm.mnc),'') from network_mncs nm where nm.network_id = networks.id) asc");

        $networks = $q->paginate($per)->appends($r->all());

        return view('networks.index', compact('networks','per'));
    }

    public function create(){
        $countries = Country::orderBy('name')->get();
        $network = new Network();
        return view('networks.create', compact('network','countries'));
    }

    public function edit(Network $network){
        $countries = Country::orderBy('name')->get();
        $network->load('mncs','country');
        return view('networks.edit', compact('network','countries'));
    }

    public function store(Request $r){
        $data = $r->validate([
            'name' => 'required|string',
            'country_id' => 'required|exists:countries,id',
            'mcc' => 'nullable|string'
        ]);
        $network = Network::create($data);
        return redirect()->route('networks.edit',$network)->with('ok','Created');
    }

    public function update(Request $r, Network $network){
        $data = $r->validate([
            'name' => 'required|string',
            'country_id' => 'required|exists:countries,id',
            'mcc' => 'nullable|string'
        ]);
        $network->fill($data)->save();

        // Handle MNC rows
        $rows = $r->input('mncs', []);
        foreach ($rows as $row){
            $id   = $row['id']   ?? null;
            $mnc  = isset($row['mnc']) ? trim((string)$row['mnc']) : null;
            $rem  = isset($row['_remove']) && $row['_remove'] ? true : false;

            if ($id && $rem){
                NetworkMnc::where('id',$id)->where('network_id',$network->id)->delete();
                continue;
            }
            if ($id && !$rem){
                $m = NetworkMnc::where('id',$id)->where('network_id',$network->id)->first();
                if ($m){
                    $m->mnc = $mnc;
                    $m->mcc = $network->mcc; // ensure primary MCC used
                    $m->mcc_mnc = $network->mcc.$mnc;
                    $m->updated_by_source = auth()->user()->name ?? null;
                    $m->save();
                }
                continue;
            }
            if (!$id && !$rem && $mnc !== null && $mnc !== ''){
                NetworkMnc::create([
                    'network_id' => $network->id,
                    'mcc' => $network->mcc,
                    'mnc' => $mnc,
                    'mcc_mnc' => $network->mcc.$mnc,
                    'created_by_source' => auth()->user()->name ?? null,
                ]);
            }
        }

        return back()->with('ok','Saved');
    }

    public function destroy(Network $network){
        $network->delete();
        return redirect()->route('networks.index')->with('ok','Deleted');
    }
}
PHP

echo "==> 3) Networks index view (import group above filters, pagination bottom, per-page selector)"
cat > resources/views/networks/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">

    <!-- Import group -->
    <div class="flex flex-wrap items-center gap-3">
      <form action="{{ route('carriers.import') }}" method="POST" class="flex items-center gap-3">
        @csrf
        <button type="submit" class="inline-flex items-center rounded bg-indigo-600 px-3 py-2 text-white hover:bg-indigo-700">
          Fresh Import
        </button>
        <span class="text-sm text-gray-600">Import Source</span>
        <select name="source" class="rounded border px-2 py-2">
          <option value="itu" {{ old('source', request('source','itu'))=='itu'?'selected':'' }}>ITU</option>
        </select>
      </form>
    </div>

    <!-- Filters -->
    <form method="GET" class="flex flex-wrap items-center gap-2 bg-white p-3 rounded shadow">
      <input name="q" value="{{ request('q') }}" placeholder="Network name"
             class="rounded border px-3 py-2">
      <input name="country" value="{{ request('country') }}" placeholder="Country"
             class="rounded border px-3 py-2">
      <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC"
             class="rounded border px-3 py-2">
      <input name="mnc" value="{{ request('mnc') }}" placeholder="MNC"
             class="rounded border px-3 py-2">
      <input name="mcc_mnc" value="{{ request('mcc_mnc') }}" placeholder="MCC-MNC"
             class="rounded border px-3 py-2">

      <select name="per" class="ml-auto rounded border px-2 py-2">
        @foreach([20,50,100,1000] as $opt)
          <option value="{{ $opt }}" {{ ($per ?? 20)==$opt ? 'selected':'' }}>{{ $opt }}</option>
        @endforeach
      </select>
      <button class="rounded bg-gray-800 text-white px-3 py-2">Filter</button>
    </form>

    <!-- Table -->
    <div class="bg-white rounded shadow overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 text-sm">
        <thead class="bg-gray-50">
          <tr class="text-left">
            <th class="px-4 py-2">Country</th>
            <th class="px-4 py-2">Network</th>
            <th class="px-4 py-2">Primary MCC</th>
            <th class="px-4 py-2">MNCs</th>
            <th class="px-4 py-2 w-28">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          @forelse($networks as $n)
            <tr>
              <td class="px-4 py-2">{{ optional($n->country)->name }}</td>
              <td class="px-4 py-2">{{ $n->name }}</td>
              <td class="px-4 py-2">{{ $n->mcc }}</td>
              <td class="px-4 py-2">
                {{ $n->mncs->pluck('mnc')->filter()->implode(', ') }}
              </td>
              <td class="px-4 py-2">
                <a href="{{ route('networks.edit', $n) }}" class="text-indigo-600 hover:underline">Edit</a>
                <form action="{{ route('networks.destroy', $n) }}" method="POST" class="inline"
                      onsubmit="return confirm('Delete this network?')">
                  @csrf @method('DELETE')
                  <button class="text-red-600 hover:underline ml-2">Delete</button>
                </form>
              </td>
            </tr>
          @empty
            <tr><td class="px-4 py-6 text-gray-500" colspan="5">No records.</td></tr>
          @endforelse
        </tbody>
      </table>
    </div>

    <!-- Pagination -->
    <div class="flex items-center justify-between">
      <div class="text-sm text-gray-600">
        Showing {{ $networks->firstItem() ?? 0 }}–{{ $networks->lastItem() ?? 0 }} of {{ $networks->total() }}
      </div>
      <div>
        {{ $networks->onEachSide(1)->links() }}
      </div>
    </div>
  </div>
</x-app-layout>
BLADE

echo "==> 4) Networks edit view (inline rows, RO MCC-MNC, quick add, single confirm on Save)"
cat > resources/views/networks/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2>
  </x-slot>

  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
    @if(session('ok'))
      <div class="rounded bg-green-50 text-green-800 px-3 py-2">{{ session('ok') }}</div>
    @endif

    <form id="network-form" method="POST" action="{{ route('networks.update',$network) }}">
      @csrf @method('PUT')

      <div class="bg-white rounded shadow p-4 space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Name</label>
          <input name="name" value="{{ old('name',$network->name) }}" class="mt-1 w-full rounded border px-3 py-2">
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700">Country</label>
          <select name="country_id" class="mt-1 w-full rounded border px-3 py-2">
            @foreach($countries as $c)
              <option value="{{ $c->id }}" {{ (old('country_id',$network->country_id)==$c->id)?'selected':'' }}>{{ $c->name }}</option>
            @endforeach
          </select>
        </div>

        <!-- Primary MCC duplicated below name -->
        <div>
          <label class="block text-sm font-medium text-gray-700">Primary MCC</label>
          <input name="mcc" value="{{ old('mcc',$network->mcc) }}" class="mt-1 w-full rounded border px-3 py-2">
        </div>
      </div>

      <div class="bg-white rounded shadow p-4 space-y-3">
        <div class="flex items-center justify-between">
          <div class="text-sm font-semibold">MNCs</div>
          <input id="quick-add-mnc" type="text" placeholder="Type MNC and press Enter"
                 class="rounded border px-3 py-2 text-sm" />
        </div>

        <div id="mncs-rows" class="space-y-2">
          @php $rows = old('mncs'); @endphp
          @if(is_array($rows))
            @foreach($rows as $i => $row)
              <div class="grid grid-cols-12 gap-2 items-center border rounded p-2">
                <input type="hidden" name="mncs[{{ $i }}][id]" value="{{ $row['id'] ?? '' }}">
                <div class="col-span-3">
                  <label class="block text-xs text-gray-600">MNC</label>
                  <input name="mncs[{{ $i }}][mnc]" value="{{ $row['mnc'] ?? '' }}" class="w-full rounded border px-2 py-1">
                </div>
                <div class="col-span-4">
                  <label class="block text-xs text-gray-600">MCC-MNC</label>
                  <input value="{{ (old('mcc',$network->mcc)).($row['mnc'] ?? '') }}" class="w-full rounded border px-2 py-1 bg-gray-100" readonly>
                </div>
                <div class="col-span-3 flex items-end">
                  <label class="inline-flex items-center gap-2 text-sm">
                    <input type="checkbox" class="mnc-remove" name="mncs[{{ $i }}][_remove]" value="1">
                    <span>Remove</span>
                  </label>
                </div>
              </div>
            @endforeach
          @else
            @foreach($network->mncs as $i => $m)
              <div class="grid grid-cols-12 gap-2 items-center border rounded p-2">
                <input type="hidden" name="mncs[{{ $i }}][id]" value="{{ $m->id }}">
                <div class="col-span-3">
                  <label class="block text-xs text-gray-600">MNC</label>
                  <input name="mncs[{{ $i }}][mnc]" value="{{ $m->mnc }}" class="w-full rounded border px-2 py-1">
                </div>
                <div class="col-span-4">
                  <label class="block text-xs text-gray-600">MCC-MNC</label>
                  <input value="{{ ($network->mcc).($m->mnc) }}" class="w-full rounded border px-2 py-1 bg-gray-100" readonly>
                </div>
                <div class="col-span-3 flex items-end">
                  <label class="inline-flex items-center gap-2 text-sm">
                    <input type="checkbox" class="mnc-remove" name="mncs[{{ $i }}][_remove]" value="1">
                    <span>Remove</span>
                  </label>
                </div>
              </div>
            @endforeach
          @endif
        </div>
      </div>

      <div class="flex justify-end">
        <button class="rounded bg-indigo-600 text-white px-4 py-2">Save</button>
      </div>
    </form>
  </div>

  <script>
    (function(){
      const form = document.getElementById('network-form');
      form.addEventListener('submit', function(ev){
        const checked = form.querySelectorAll('.mnc-remove:checked').length;
        if (checked > 0) {
          if (!confirm('Remove '+checked+' MNC(s)?')) {
            ev.preventDefault();
          }
        }
      });

      const quick = document.getElementById('quick-add-mnc');
      const rows = document.getElementById('mncs-rows');
      function nextIndex(){
        const inputs = rows.querySelectorAll('input[name^="mncs["][name$="[mnc]"]');
        if (!inputs.length) return 0;
        let max = -1;
        inputs.forEach(inp=>{
          const m = inp.name.match(/^mncs\[(\d+)\]/);
          if (m) max = Math.max(max, parseInt(m[1],10));
        });
        return max+1;
      }
      quick.addEventListener('keydown', function(e){
        if (e.key === 'Enter') {
          e.preventDefault();
          const mnc = quick.value.trim();
          if (!mnc) return;
          const idx = nextIndex();
          const mcc = document.querySelector('input[name="mcc"]').value || '';
          const wrap = document.createElement('div');
          wrap.className = 'grid grid-cols-12 gap-2 items-center border rounded p-2';
          wrap.innerHTML = `
            <input type="hidden" name="mncs[${idx}][id]" value="">
            <div class="col-span-3">
              <label class="block text-xs text-gray-600">MNC</label>
              <input name="mncs[${idx}][mnc]" value="${mnc}" class="w-full rounded border px-2 py-1">
            </div>
            <div class="col-span-4">
              <label class="block text-xs text-gray-600">MCC-MNC</label>
              <input value="${mcc}${mnc}" class="w-full rounded border px-2 py-1 bg-gray-100" readonly>
            </div>
            <div class="col-span-3 flex items-end">
              <label class="inline-flex items-center gap-2 text-sm">
                <input type="checkbox" class="mnc-remove" name="mncs[${idx}][_remove]" value="1">
                <span>Remove</span>
              </label>
            </div>`;
          rows.appendChild(wrap);
          quick.value = '';
        }
      });
    })();
  </script>
</x-app-layout>
BLADE

echo "==> 5) Import command (switch to onomondo JSON, keep local data, upsert mncs)"
cat > app/Console/Commands/ImportCarriers.php <<'PHP'
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use App\Models\Country;
use App\Models\CountryMcc;
use App\Models\Network;
use App\Models\NetworkMnc;
use Illuminate\Support\Str;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--source=itu} {--fresh}';
    protected $description = 'Import carriers from external sources (multi-MNC aware)';

    public function handle(){
        $source = strtolower($this->option('source') ?? 'itu');

        if ($this->option('fresh')) {
            \DB::statement('TRUNCATE network_mncs RESTART IDENTITY CASCADE');
            \DB::statement('TRUNCATE country_mccs RESTART IDENTITY CASCADE');
            $this->info('Cleared network_mncs & country_mccs (networks kept).');
        }

        if ($source === 'itu') {
            return $this->importOnomondo();
        }

        $this->error("Unknown source: {$source}");
        return 1;
    }

    protected function importOnomondo(){
        $urls = [
            'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/data.json',
            'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/data.json',
        ];
        $json = null;
        foreach ($urls as $u){
            try {
                $resp = Http::timeout(30)->get($u);
                if ($resp->ok() && $resp->body()){
                    $json = $resp->body();
                    break;
                }
            } catch (\Throwable $e) { /* try next */ }
        }
        if (!$json){
            $this->error('Cannot fetch ITU JSON');
            return 1;
        }
        Storage::put('carriers/itu/data.json', $json);
        $rows = json_decode($json, true);
        if (!is_array($rows)){
            $this->error('Bad JSON format');
            return 1;
        }

        $imported = 0;
        foreach ($rows as $row){
            $mcc = trim((string)($row['mcc'] ?? $row['MCC'] ?? ''));
            $mnc = trim((string)($row['mnc'] ?? $row['MNC'] ?? ''));
            if ($mcc === '' || $mnc === '') continue;

            $iso2 = strtolower(trim((string)($row['alpha_2'] ?? $row['iso'] ?? $row['iso2'] ?? '')));
            if ($iso2 && strlen($iso2) !== 2) $iso2 = ''; // ignore weird tokens like 'n/a'

            $countryName = trim((string)($row['country'] ?? $row['country_name'] ?? $row['Country'] ?? ''));
            $brand = trim((string)($row['brand'] ?? $row['network'] ?? $row['operator'] ?? $row['name'] ?? 'Unknown'));

            // Country: by iso2 if valid, else by name (ilike)
            $country = null;
            if ($iso2){
                $country = Country::where('iso2',$iso2)->first();
            }
            if (!$country && $countryName){
                $country = Country::where('name','ilike',$countryName)->first();
            }
            if (!$country){
                $country = Country::firstOrCreate(
                    ['name' => $countryName ?: 'International Networks'],
                    ['iso2' => null]
                );
            }

            // Record country MCC once
            CountryMcc::firstOrCreate(['country_id'=>$country->id,'mcc'=>$mcc]);

            // Network: unique by (country_id, lower(name))
            $net = Network::where('country_id',$country->id)
                ->whereRaw('lower(name)=lower(?)',[$brand ?: 'Unknown'])
                ->first();

            if (!$net){
                $net = Network::create([
                    'country_id' => $country->id,
                    'name' => $brand ?: 'Unknown',
                    'mcc'  => $mcc, // primary MCC initial
                    'created_by_source' => 'ITU import',
                ]);
            } else {
                // Do not overwrite primary MCC if already set; otherwise set it
                if (!$net->mcc) $net->mcc = $mcc;
                $net->updated_by_source = 'ITU import';
                $net->save();
            }

            // Upsert the MNC entry (global uniqueness by mcc_mnc is OK)
            $mm = $mcc.$mnc;
            $m = NetworkMnc::where('mcc_mnc',$mm)->first();
            if (!$m){
                NetworkMnc::create([
                    'network_id' => $net->id,
                    'mcc' => $mcc,
                    'mnc' => $mnc,
                    'mcc_mnc' => $mm,
                    'created_by_source' => 'ITU import',
                ]);
            } else {
                if ($m->network_id !== $net->id){
                    // If JSON moved operator between names, prefer current network but keep MNC attached to existing network
                    // (no delete)
                }
            }
            $imported++;
        }

        $this->info("Imported/updated rows: {$imported}");
        return 0;
    }
}
PHP

echo "==> 6) Re-cache"
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "Done."
