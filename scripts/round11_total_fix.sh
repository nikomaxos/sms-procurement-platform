#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

# --- CountriesController (full, clean) ---
F=app/Http/Controllers/CountriesController.php
b "$F"
mkdir -p "$(dirname "$F")"
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
            ->orderBy('name', 'asc')
            ->paginate($per);
        return view('countries.index', compact('countries'));
    }

    public function edit(Country $country)
    {
        $country->load('mccs');
        $mccs = $country->mccs;
        return view('countries.edit', compact('country','mccs'));
    }
}
PHP

# --- NetworksController (full, clean) ---
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
            ->with(['country','mncs' => function($qq){ $qq->orderBy('mnc'); }])
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
        return redirect()->route('networks.edit', $n)->with('status','Created.');
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

        // Primary MCC: first from network->country->mccs if available.
        $primaryMcc = (string) optional(optional($network->country)->mccs->first())->mcc ?? '';

        foreach ($mncs as $row) {
            $id  = isset($row['id']) ? (int)$row['id'] : null;
            $mnc = isset($row['mnc']) ? trim((string)$row['mnc']) : '';
            if ($mnc === '') continue;

            $nm = $id
                ? NetworkMnc::where('network_id',$network->id)->where('id',$id)->first()
                : new NetworkMnc();

            if (!$nm) { $nm = new NetworkMnc(); }
            $nm->network_id = $network->id;
            $nm->mcc = $primaryMcc;      // if empty, model will try to infer
            $nm->mnc = $mnc;
            $nm->save();                  // model computes mcc_mnc
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

# --- NetworkMnc model: compute mcc_mnc & fallback MCC from relation ---
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
            // If MCC empty, try infer from related network->country->mccs first()
            if (empty($m->mcc) && $m->relationLoaded('network')) {
                $m->mcc = (string) optional(optional($m->network->country)->mccs->first())->mcc ?? $m->mcc;
            } elseif (empty($m->mcc) && $m->network_id) {
                $net = Network::with('country.mccs')->find($m->network_id);
                if ($net) $m->mcc = (string) optional(optional($net->country)->mccs->first())->mcc ?? $m->mcc;
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

# --- Networks index blade (Actions column restored) ---
F=resources/views/networks/index.blade.php
b "$F"
cat > "$F" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
    <!-- Actions -->
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
              <td class="px-4 py-2">
                {{ $n->mncs->pluck('mnc')->implode(', ') }}
              </td>
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

# --- Networks create blade (no partial dependency) ---
F=resources/views/networks/create.blade.php
b "$F"
cat > "$F" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Create Network</h2>
  </x-slot>

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
          @foreach($countries as $c)
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

# --- Networks edit blade (safe MCC access + single confirm) ---
F=resources/views/networks/edit.blade.php
b "$F"
cat > "$F" <<'BLADE'
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
          @php $primaryMcc = $network->country?->mccs?->first()?->mcc ?? ''; @endphp
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
      if (anyDelete && !confirm('Remove selected MNCs?')) {
        e.preventDefault();
      }
    });

    const tmpl = document.getElementById('mnc-template').innerHTML;
    const rows = document.getElementById('mnc-rows');
    const quick = document.getElementById('quick-mnc');
    const mccInput = document.getElementById('primary-mcc-val');
    const currentMcc = () => (mccInput?.value || '');

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
        node.querySelector('input[readonly]').value = currentMcc() + val;
        rows.appendChild(node);
        quick.value = '';
      }
    });

    rows.addEventListener('input', function(e){
      if (e.target.name && e.target.name.endsWith('[mnc]')) {
        const wrapper = e.target.closest('.grid');
        wrapper.querySelector('input[readonly]').value = currentMcc() + e.target.value;
      }
    });
  })();
  </script>
</x-app-layout>
BLADE

# --- Warm caches ---
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "Round 11 applied: controllers + views + model fixed."
