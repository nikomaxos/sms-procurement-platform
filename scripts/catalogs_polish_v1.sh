#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

mkdir -p app/Http/Controllers resources/views/{countries,networks} resources/views/partials

##############################################################################
# 0) Sidebar: show plain text titles (no icon text leaking)
##############################################################################
PARTIAL=resources/views/partials/catalog_links.blade.php
if [ -f "$PARTIAL" ]; then
  cp -a "$PARTIAL" "$PARTIAL.bak.$(date +%F_%H-%M-%S)"
fi
cat > "$PARTIAL" <<'BLADE'
<div class="mb-2">
  <div class="px-3 py-2 text-xs uppercase tracking-wide text-gray-500">Catalogs</div>
  <a href="{{ route('countries.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
    <span>Countries</span>
  </a>
  <a href="{{ route('networks.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
    <span>Networks</span>
  </a>
</div>
BLADE

SID="resources/views/partials/sidebar.blade.php"
if [ -f "$SID" ]; then
  cp -a "$SID" "$SID.bak.$(date +%F_%H-%M-%S)"
  # remove any previous inline links then include once before Settings
  awk '!/route\(.?countries\.index/ && !/route\(.?networks\.index/' "$SID" > "$SID.tmp" && mv "$SID.tmp" "$SID"
  awk '
    BEGIN{ins=0}
    {
      if(ins==0 && $0 ~ /route\(.?settings\./){
        print "@include('\''partials.catalog_links'\'')"
        ins=1
      }
      print
    }
    END{
      if(ins==0){ print "@include('\''partials.catalog_links'\'')" }
    }
  ' "$SID" > "$SID.new" && mv "$SID.new" "$SID"
fi

##############################################################################
# 1) Controllers: paging, filters, delete, MCC-MNC recompute
##############################################################################
cat > app/Http/Controllers/CountriesController.php <<'PHP'
<?php
namespace App\Http\Controllers;

use App\Models\Country;
use App\Models\CountryMcc;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CountriesController extends Controller {
    public function __construct(){ $this->middleware('auth'); }

    public function index(Request $r){
        $allowed=[20,50,100,1000]; $per=(int)$r->integer('per',20); if(!in_array($per,$allowed,true)) $per=20;
        $q=trim((string)$r->query('q',''));
        $mcc=trim((string)$r->query('mcc',''));

        $rows = Country::with('mccs')
            ->when($q!=='', fn($qq)=>$qq->where('name','ilike','%'.$q.'%'))
            ->when($mcc!=='', function($qq) use($mcc){
                $qq->whereExists(function($q2) use($mcc){
                    $q2->from('country_mccs')->whereColumn('country_mccs.country_id','countries.id')
                       ->where('country_mccs.mcc', $mcc);
                });
            })
            ->orderBy('name')
            ->paginate($per)->withQueryString();

        return view('countries.index', compact('rows','per','q','mcc'));
    }

    public function create(){
        $country = new Country();
        $mccs = [];
        return view('countries.create', compact('country','mccs'));
    }

    public function store(Request $r){
        $data = $r->validate([
            'name'=>'required|string|max:120',
            'iso2'=>'nullable|regex:/^[a-z]{2}$/i',
            'mccs'=>'array',
            'mccs.*'=>'string|size:3'
        ]);
        $country = Country::create(['name'=>$data['name'],'iso2'=>isset($data['iso2'])?strtolower($data['iso2']):null]);
        $this->syncMccs($country->id, $data['mccs'] ?? []);
        return redirect()->route('countries.index')->with('status','Country created.');
    }

    public function edit(Country $country){
        $mccs = $country->mccs()->pluck('mcc')->all();
        return view('countries.edit', compact('country','mccs'));
    }

    public function update(Request $r, Country $country){
        $data = $r->validate([
            'name'=>'required|string|max:120',
            'iso2'=>'nullable|regex:/^[a-z]{2}$/i',
            'mccs'=>'array',
            'mccs.*'=>'string|size:3'
        ]);
        $country->name=$data['name'];
        $country->iso2=isset($data['iso2'])?strtolower($data['iso2']):null;
        $country->save();
        $this->syncMccs($country->id, $data['mccs'] ?? []);
        return redirect()->route('countries.index')->with('status','Country updated.');
    }

    public function destroy(Country $country){
        $country->delete();
        return redirect()->route('countries.index')->with('status','Country deleted.');
    }

    private function syncMccs(int $countryId, array $mccs): void {
        $mccs = array_values(array_unique(array_map(fn($x)=>str_pad(preg_replace('/\D/','',$x),3,'0',STR_PAD_LEFT), $mccs)));
        DB::table('country_mccs')->where('country_id',$countryId)->delete();
        foreach ($mccs as $m) {
            CountryMcc::firstOrCreate(['mcc'=>$m], ['country_id'=>$countryId]);
        }
    }

    // Typeahead already added earlier as countries.lookup
}
PHP

cat > app/Http/Controllers/NetworksController.php <<'PHP'
<?php
namespace App\Http\Controllers;

use App\Models\Network;
use App\Models\Country;
use Illuminate\Http\Request;

class NetworksController extends Controller {
    public function __construct(){ $this->middleware('auth'); }

    public function index(Request $r){
        $allowed=[20,50,100,1000]; $per=(int)$r->integer('per',20); if(!in_array($per,$allowed,true)) $per=20;
        $q=trim((string)$r->query('q',''));
        $mcc=trim((string)$r->query('mcc',''));
        $mnc=trim((string)$r->query('mnc',''));
        $key=trim((string)$r->query('mcc_mnc',''));
        $country=trim((string)$r->query('country',''));

        $rows = Network::with('country')
            ->when($q!=='', fn($qq)=>$qq->where('name','ilike','%'.$q.'%'))
            ->when($mcc!=='', fn($qq)=>$qq->where('mcc', str_pad(preg_replace('/\D/','',$mcc),3,'0',STR_PAD_LEFT)))
            ->when($mnc!=='', fn($qq)=>$qq->where('mnc', $mnc))
            ->when($key!=='', fn($qq)=>$qq->where('mcc_mnc', strtoupper($key)))
            ->when($country!=='', fn($qq)=>$qq->whereHas('country', fn($qc)=>$qc->where('name','ilike','%'.$country.'%')))
            ->orderBy('name')
            ->paginate($per)->withQueryString();

        return view('networks.index', compact('rows','per','q','mcc','mnc','key','country'));
    }

    public function create(){
        $network = new Network();
        $countries = Country::orderBy('name')->get(['id','name']);
        return view('networks.create', compact('network','countries'));
    }

    public function store(Request $r){
        $data = $r->validate([
            'name'=>'required|string|max:160',
            'mcc'=>'required|string|size:3',
            'mnc'=>'required|string|max:3',
            'country_id'=>'nullable|exists:countries,id',
        ]);
        $mcc = str_pad(preg_replace('/\D/','',$data['mcc']),3,'0',STR_PAD_LEFT);
        $mnc = strtoupper($data['mnc']); // keep original (2/3 chars)
        $mncKey = str_pad(preg_replace('/\D/','',$mnc),3,'0',STR_PAD_LEFT);
        $key = $mcc.$mncKey;

        $n = new Network();
        $n->name = $data['name'];
        $n->mcc = $mcc;
        $n->mnc = $mnc;
        $n->mcc_mnc = $key;
        $n->country_id = $data['country_id'] ?? null;
        $n->save();

        return redirect()->route('networks.index')->with('status','Network created.');
    }

    public function edit(Network $network){
        $countries = Country::orderBy('name')->get(['id','name']);
        return view('networks.edit', compact('network','countries'));
    }

    public function update(Request $r, Network $network){
        $data = $r->validate([
            'name'=>'required|string|max:160',
            'mcc'=>'required|string|size:3',
            'mnc'=>'required|string|max:3',
            'country_id'=>'nullable|exists:countries,id',
        ]);
        $mcc = str_pad(preg_replace('/\D/','',$data['mcc']),3,'0',STR_PAD_LEFT);
        $mnc = strtoupper($data['mnc']);
        $mncKey = str_pad(preg_replace('/\D/','',$mnc),3,'0',STR_PAD_LEFT);
        $key = $mcc.$mncKey;

        $network->name = $data['name'];
        $network->mcc = $mcc;
        $network->mnc = $mnc;
        $network->mcc_mnc = $key;
        $network->country_id = $data['country_id'] ?? null;
        $network->save();

        return redirect()->route('networks.index')->with('status','Network updated.');
    }

    public function destroy(Network $network){
        $network->delete();
        return redirect()->route('networks.index')->with('status','Network deleted.');
    }
}
PHP

##############################################################################
# 2) Views: paging controls, filters, delete buttons, MCC-MNC read-only
##############################################################################
# Countries index
cat > resources/views/countries/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Countries</h2></x-slot>
  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <form method="GET" class="flex items-center gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Country name…" class="rounded border px-3 py-2">
        <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC…" class="rounded border px-3 py-2 w-28">
        <select name="per" class="rounded border px-2 py-2">
          @foreach([20,50,100,1000] as $n)
            <option value="{{ $n }}" @selected((int)request('per',20)===$n)>{{ $n }}/page</option>
          @endforeach
        </select>
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      </form>
      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-2">
        @csrf
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Update from source</button>
        <input type="hidden" name="fresh" value="1">
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700" onclick="return confirm('Full refresh?')">Fresh import</button>
      </form>
      <a href="{{ route('countries.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Country</a>
    </div>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">ISO2</th>
            <th class="px-3 py-2 text-left">MCCs</th>
            <th class="px-3 py-2 text-left">Created</th>
            <th class="px-3 py-2 text-left">Updated</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($rows as $c)
          <tr class="border-t">
            <td class="px-3 py-2">{{ $c->name }}</td>
            <td class="px-3 py-2">{{ $c->iso2 }}</td>
            <td class="px-3 py-2">
              @foreach(($c->mccs ?? []) as $m)
                <span class="inline-block rounded bg-gray-100 px-2 py-0.5 mr-1">{{ $m->mcc }}</span>
              @endforeach
            </td>
            <td class="px-3 py-2">{{ optional($c->created_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2">{{ optional($c->updated_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2 text-right">
              <a href="{{ route('countries.edit',$c) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
              <form method="POST" action="{{ route('countries.destroy',$c) }}" class="inline"
                    onsubmit="return confirm('Delete country?');">
                @csrf @method('DELETE')
                <button class="rounded px-3 py-2 bg-red-600 text-white hover:bg-red-700">Delete</button>
              </form>
            </td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4 flex items-center justify-between">
      <form method="GET" class="flex items-center gap-2">
        <input type="hidden" name="q" value="{{ request('q') }}">
        <input type="hidden" name="mcc" value="{{ request('mcc') }}">
        <select name="per" class="rounded border px-2 py-2">
          @foreach([20,50,100,1000] as $n)
            <option value="{{ $n }}" @selected((int)request('per',20)===$n)>{{ $n }}/page</option>
          @endforeach
        </select>
        <button class="rounded bg-blue-600 px-3 py-2 text-white hover:bg-blue-700">Apply</button>
      </form>
      <div>{{ $rows->appends(request()->query())->links() }}</div>
    </div>
  </div>
</x-app-layout>
BLADE

# Countries create/edit reuse existing partials if you already have them; otherwise lightweight forms:
cat > resources/views/countries/create.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Add Country</h2></x-slot>
  <div class="py-6 max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('countries.store') }}" class="space-y-4">
      @csrf
      <div>
        <label class="block text-sm font-medium">Name</label>
        <input name="name" class="mt-1 w-full rounded border px-3 py-2" required>
      </div>
      <div>
        <label class="block text-sm font-medium">ISO2</label>
        <input name="iso2" maxlength="2" class="mt-1 w-28 rounded border px-3 py-2" placeholder="eg gr">
      </div>
      <div>
        <label class="block text-sm font-medium">MCCs (comma separated)</label>
        <input name="mccs_raw" class="mt-1 w-full rounded border px-3 py-2" placeholder="eg 202, 204">
      </div>
      <script>
        // convert mccs_raw to array on submit
        document.addEventListener('DOMContentLoaded',()=> {
          const f=document.forms[0];
          f.addEventListener('submit', ()=>{
            const raw=(f.mccs_raw.value||'').split(',').map(s=>s.trim()).filter(Boolean);
            raw.forEach(v=>{
              const i=document.createElement('input'); i.type='hidden'; i.name='mccs[]'; i.value=v; f.appendChild(i);
            });
          });
        });
      </script>
      <div class="flex gap-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('countries.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

cat > resources/views/countries/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Country</h2></x-slot>
  <div class="py-6 max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('countries.update',$country) }}" class="space-y-4">
      @csrf @method('PUT')
      <div>
        <label class="block text-sm font-medium">Name</label>
        <input name="name" class="mt-1 w-full rounded border px-3 py-2" value="{{ $country->name }}" required>
      </div>
      <div>
        <label class="block text-sm font-medium">ISO2</label>
        <input name="iso2" maxlength="2" class="mt-1 w-28 rounded border px-3 py-2" value="{{ $country->iso2 }}">
      </div>
      <div>
        <label class="block text-sm font-medium">MCCs (comma separated)</label>
        <input name="mccs_raw" class="mt-1 w-full rounded border px-3 py-2" value="{{ implode(', ', $mccs) }}">
      </div>
      <script>
        document.addEventListener('DOMContentLoaded',()=> {
          const f=document.forms[0];
          f.addEventListener('submit', ()=>{
            const raw=(f.mccs_raw.value||'').split(',').map(s=>s.trim()).filter(Boolean);
            raw.forEach(v=>{
              const i=document.createElement('input'); i.type='hidden'; i.name='mccs[]'; i.value=v; f.appendChild(i);
            });
          });
        });
      </script>
      <div class="flex gap-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('countries.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

# Networks index
cat > resources/views/networks/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2></x-slot>
  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-2 mb-4">
      <form method="GET" class="flex flex-wrap items-center gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Network name…" class="rounded border px-3 py-2">
        <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC…" class="rounded border px-3 py-2 w-28">
        <input name="mnc" value="{{ request('mnc') }}" placeholder="MNC…" class="rounded border px-3 py-2 w-28">
        <input name="mcc_mnc" value="{{ request('mcc_mnc') }}" placeholder="MCC-MNC…" class="rounded border px-3 py-2 w-36">
        <input name="country" value="{{ request('country') }}" placeholder="Country…" class="rounded border px-3 py-2">
        <select name="per" class="rounded border px-2 py-2">
          @foreach([20,50,100,1000] as $n)
            <option value="{{ $n }}" @selected((int)request('per',20)===$n)>{{ $n }}/page</option>
          @endforeach
        </select>
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      </form>
      <a href="{{ route('networks.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Network</a>
    </div>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Network</th>
            <th class="px-3 py-2 text-left">MCC</th>
            <th class="px-3 py-2 text-left">MNC</th>
            <th class="px-3 py-2 text-left">MCC-MNC</th>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">Created</th>
            <th class="px-3 py-2 text-left">Updated</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($rows as $n)
          <tr class="border-t">
            <td class="px-3 py-2">{{ $n->name }}</td>
            <td class="px-3 py-2">{{ $n->mcc }}</td>
            <td class="px-3 py-2">{{ $n->mnc }}</td>
            <td class="px-3 py-2 font-mono">{{ $n->mcc_mnc }}</td>
            <td class="px-3 py-2">{{ optional($n->country)->name }}</td>
            <td class="px-3 py-2">{{ optional($n->created_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2">{{ optional($n->updated_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2 text-right">
              <a href="{{ route('networks.edit',$n) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
              <form method="POST" action="{{ route('networks.destroy',$n) }}" class="inline"
                    onsubmit="return confirm('Delete network?');">
                @csrf @method('DELETE')
                <button class="rounded px-3 py-2 bg-red-600 text-white hover:bg-red-700">Delete</button>
              </form>
            </td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4 flex items-center justify-between">
      <form method="GET" class="flex items-center gap-2">
        <input type="hidden" name="q" value="{{ request('q') }}">
        <input type="hidden" name="mcc" value="{{ request('mcc') }}">
        <input type="hidden" name="mnc" value="{{ request('mnc') }}">
        <input type="hidden" name="mcc_mnc" value="{{ request('mcc_mnc') }}">
        <input type="hidden" name="country" value="{{ request('country') }}">
        <select name="per" class="rounded border px-2 py-2">
          @foreach([20,50,100,1000] as $n)
            <option value="{{ $n }}" @selected((int)request('per',20)===$n)>{{ $n }}/page</option>
          @endforeach
        </select>
        <button class="rounded bg-blue-600 px-3 py-2 text-white hover:bg-blue-700">Apply</button>
      </form>
      <div>{{ $rows->appends(request()->query())->links() }}</div>
    </div>
  </div>
</x-app-layout>
BLADE

# Networks create/edit with read-only MCC-MNC
cat > resources/views/networks/_form.blade.php <<'BLADE'
@php
  $isEdit = isset($network) && $network->id;
  $mccVal = old('mcc', $network->mcc ?? '');
  $mncVal = old('mnc', $network->mnc ?? '');
  $keyVal = sprintf('%03s', preg_replace('/\D/','',$mccVal)) . sprintf('%03s', preg_replace('/\D/','',$mncVal));
@endphp
<div class="space-y-4">
  <div>
    <label class="block text-sm font-medium">Name</label>
    <input name="name" class="mt-1 w-full rounded border px-3 py-2" value="{{ old('name',$network->name ?? '') }}" required>
  </div>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <div>
      <label class="block text-sm font-medium">MCC</label>
      <input name="mcc" maxlength="3" class="mt-1 w-full rounded border px-3 py-2" value="{{ $mccVal }}" required>
    </div>
    <div>
      <label class="block text-sm font-medium">MNC</label>
      <input name="mnc" maxlength="3" class="mt-1 w-full rounded border px-3 py-2" value="{{ $mncVal }}" required>
    </div>
    <div>
      <label class="block text-sm font-medium">MCC-MNC (auto)</label>
      <input name="mcc_mnc_display" class="mt-1 w-full rounded border px-3 py-2 font-mono bg-gray-50" value="{{ $keyVal }}" readonly>
    </div>
  </div>
  <div>
    <label class="block text-sm font-medium">Country</label>
    <select name="country_id" class="mt-1 w-full rounded border px-3 py-2">
      <option value="">—</option>
      @foreach($countries as $c)
        <option value="{{ $c->id }}" @selected(old('country_id', $network->country_id ?? '')==$c->id)>{{ $c->name }}</option>
      @endforeach
    </select>
  </div>
</div>
<script>
document.addEventListener('DOMContentLoaded', ()=>{
  const mcc=document.querySelector('input[name="mcc"]');
  const mnc=document.querySelector('input[name="mnc"]');
  const out=document.querySelector('input[name="mcc_mnc_display"]');
  function pad3(s){ s=(s||'').replace(/\D/g,''); return s.padStart(3,'0').slice(0,3); }
  function refresh(){ out.value = pad3(mcc.value)+pad3(mnc.value); }
  mcc.addEventListener('input', refresh);
  mnc.addEventListener('input', refresh);
});
</script>
BLADE

cat > resources/views/networks/create.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Add Network</h2></x-slot>
  <div class="py-6 max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.store') }}" class="space-y-4">
      @csrf
      @include('networks._form')
      <div class="flex gap-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

cat > resources/views/networks/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2></x-slot>
  <div class="py-6 max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.update',$network) }}" class="space-y-4">
      @csrf @method('PUT')
      @include('networks._form')
      <div class="flex gap-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

##############################################################################
# 3) Ensure resource routes are present (including destroy)
##############################################################################
if ! grep -q "countries.index" routes/web.php 2>/dev/null; then
  cat >> routes/web.php <<'PHP'
Route::resource('countries', \App\Http\Controllers\CountriesController::class)->middleware(['auth']);
PHP
fi
if ! grep -q "networks.index" routes/web.php 2>/dev/null; then
  cat >> routes/web.php <<'PHP'
Route::resource('networks', \App\Http\Controllers\NetworksController::class)->middleware(['auth']);
PHP
fi

##############################################################################
# 4) Warm caches
##############################################################################
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "Done."
