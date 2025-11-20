#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"; b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step5c: Repair vanilla search + UI + API + guards"

############################################
# 0) Ensure partials/flash_log
############################################
mkdir -p resources/views/partials
F=resources/views/partials/flash_log.blade.php
if [ ! -f "$F" ]; then
cat > "$F" <<'BLADE'
@if (session('status') || session('error') || session('log'))
  <div class="mb-4 rounded border @if(session('error')) border-red-300 bg-red-50 @else border-green-300 bg-green-50 @endif p-3">
    @if (session('status'))
      <div class="font-semibold mb-1 text-green-800">{{ session('status') }}</div>
    @endif
    @if (session('error'))
      <div class="font-semibold mb-1 text-red-700">{{ session('error') }}</div>
    @endif
    @if (session('log'))
      <ul class="list-disc list-inside text-sm text-gray-700">
        @foreach (session('log') as $line)
          <li>{{ $line }}</li>
        @endforeach
      </ul>
    @endif
  </div>
@endif
BLADE
fi

############################################
# 1) networks/_form.blade.php (vanilla JS)
############################################
F=resources/views/networks/_form.blade.php
b "$F"
cat > "$F" <<'BLADE'
@php
    $currentCountryId   = old('country_id', $network->country_id ?? null);
    $currentCountryName = old('country_name', $network->country->name ?? '');
@endphp
@csrf
<div id="netform" class="grid grid-cols-1 md:grid-cols-2 gap-3">
    <input type="hidden" name="country_id" id="nf_country_id" value="{{ $currentCountryId }}">
    <input type="hidden" name="selected_mcc" id="nf_selected_mcc" value="{{ old('selected_mcc') }}">

    <div class="md:col-span-1">
        <label class="block text-sm font-medium mb-1">Χώρα</label>
        <div class="relative">
            <input id="nf_country_search"
                   class="border rounded w-full p-2"
                   type="text"
                   placeholder="Αναζήτηση χώρας..."
                   autocomplete="off"
                   value="{{ $currentCountryName }}">
            <div id="nf_results"
                 class="hidden absolute z-10 mt-1 w-full bg-white border rounded shadow max-h-64 overflow-auto"></div>
        </div>
        @error('country_id') <div class="text-red-600 text-sm mt-1">{{ $message }}</div> @enderror
    </div>

    <div class="md:col-span-1">
        <label class="block text-sm font-medium mb-1">MCC (μόνο από χώρα)</label>
        <input id="nf_mcc_display" class="border rounded w-full p-2 bg-gray-100" type="text" readonly>
        <div class="mt-2"><div id="nf_mcc_chips" class="flex flex-wrap gap-1"></div></div>
    </div>

    <div class="md:col-span-2">
        <label class="block text-sm font-medium mb-1">Name</label>
        <input class="border rounded w-full p-2" type="text" name="name" value="{{ old('name', $network->name ?? '') }}" required>
        @error('name') <div class="text-red-600 text-sm mt-1">{{ $message }}</div> @enderror
    </div>
</div>

<script>
(function(){
  const $ = (sel, root=document) => root.querySelector(sel);
  const root = document.getElementById('netform'); if(!root) return;

  const inCountryId   = $('#nf_country_id', root);
  const inCountryName = $('#nf_country_search', root);
  const boxResults    = $('#nf_results', root);
  const inSelMcc      = $('#nf_selected_mcc', root);
  const mccDisplay    = $('#nf_mcc_display', root);
  const mccChips      = $('#nf_mcc_chips', root);

  let lastResults = [];

  function showResults(list){
    boxResults.innerHTML = '';
    if(!list || !list.length){ boxResults.classList.add('hidden'); return; }
    list.forEach(item=>{
      const div = document.createElement('div');
      div.className = 'px-3 py-2 hover:bg-gray-50 cursor-pointer';
      const mccTxt = (item.mccs && item.mccs.length) ? ` (MCC: ${item.mccs.join(', ')})` : '';
      div.textContent = item.name + mccTxt;
      div.addEventListener('click', ()=>selectCountry(item));
      boxResults.appendChild(div);
    });
    boxResults.classList.remove('hidden');
  }

  async function fetchSearch(q){
    const r = await fetch(`/api/countries/search?q=${encodeURIComponent(q)}&limit=20`);
    if(!r.ok) return showResults([]);
    lastResults = await r.json();
    showResults(lastResults);
  }

  async function fetchMccs(countryId){
    const r = await fetch(`/api/countries/${countryId}/mccs`);
    if(!r.ok) return [];
    const j = await r.json();
    return Array.isArray(j.mccs) ? j.mccs : [];
  }

  function renderMccs(mccs){
    mccChips.innerHTML = '';
    if(!mccs.length){ mccDisplay.value=''; inSelMcc.value=''; return; }
    if(!inSelMcc.value || !mccs.includes(inSelMcc.value)) inSelMcc.value = mccs[0];
    mccDisplay.value = inSelMcc.value;
    mccs.forEach(m=>{
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'inline-block px-2 py-1 text-xs rounded border ' + (m===inSelMcc.value ? 'bg-gray-800 text-white' : 'bg-gray-100');
      btn.textContent = m;
      btn.addEventListener('click', ()=>{ inSelMcc.value=m; mccDisplay.value=m; renderMccs(mccs); });
      mccChips.appendChild(btn);
    });
  }

  async function selectCountry(item){
    inCountryId.value   = item.id;
    inCountryName.value = item.name;
    boxResults.classList.add('hidden');
    const mccs = item.mccs && item.mccs.length ? item.mccs : await fetchMccs(item.id);
    renderMccs(mccs);
  }

  inCountryName.addEventListener('input', (e)=>{
    const q = e.target.value.trim();
    if(!q){ lastResults=[]; showResults([]); return; }
    fetchSearch(q);
  });
  inCountryName.addEventListener('focus', ()=>{ if(lastResults.length) boxResults.classList.remove('hidden'); });
  document.addEventListener('click', (e)=>{ if(!root.contains(e.target)) boxResults.classList.add('hidden'); });
  inCountryName.addEventListener('keydown', (e)=>{ if(e.key==='Escape') boxResults.classList.add('hidden'); });

  // Prefill on edit
  (async function init(){
    const cid = inCountryId.value;
    if(cid){ renderMccs(await fetchMccs(cid)); } else { renderMccs([]); }
  })();
})();
</script>
BLADE

############################################
# 2) networks/create & edit wrappers
############################################
F=resources/views/networks/create.blade.php
b "$F"
cat > "$F" <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">New Network</h2></x-slot>
  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    @include('partials.flash_log')
    <form method="POST" action="{{ route('networks.store') }}" class="bg-white rounded shadow p-4">
      @include('networks._form', ['network' => $network])
      <div class="mt-4">
        <button class="rounded bg-blue-600 text-white px-4 py-2" type="submit">Create</button>
        <a class="ml-3 text-gray-600 hover:underline" href="{{ route('networks.index') }}">Cancel</a>
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
  <div class="py-6 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
    @include('partials.flash_log')
    <form method="POST" action="{{ route('networks.update', $network->id) }}" class="bg-white rounded shadow p-4 mb-6">
      @method('PUT')
      @include('networks._form', ['network' => $network])
      <div class="mt-4">
        <button class="rounded bg-blue-600 text-white px-4 py-2" type="submit">Save</button>
        <a class="ml-3 text-gray-600 hover:underline" href="{{ route('networks.index') }}">Back</a>
      </div>
    </form>

    <div class="bg-white rounded shadow p-4">
      <div class="font-semibold mb-2">MNCs</div>
      <form class="mb-3 flex flex-wrap items-center gap-2" method="POST" action="{{ route('networks.mncs.store', $network->id) }}">
        @csrf
        <div>
          <label class="block text-xs text-gray-500 mb-1">MCC</label>
          <input class="border rounded p-2 w-28 bg-gray-100" type="text" id="nf_mcc_display_clone" readonly>
          <input type="hidden" name="mcc" id="nf_mcc_hidden">
        </div>
        <div>
          <label class="block text-xs text-gray-500 mb-1">MNC</label>
          <input class="border rounded p-2 w-24" type="text" name="mnc" placeholder="MNC" required>
        </div>
        <div><button class="rounded bg-gray-800 text-white px-3 py-2" type="submit" id="nf_add_btn" disabled>Add</button></div>
      </form>

      @php $links = $network->mncs()->orderBy('mcc')->orderBy('mnc')->get(); @endphp
      @forelse ($links as $link)
        <form method="POST" class="inline-block mr-2 mb-2"
              action="{{ route('networks.mncs.destroy', [$network->id, $link->mcc, $link->mnc]) }}">
          @csrf @method('DELETE')
          <button class="inline-flex items-center gap-2 px-2 py-1 text-xs rounded bg-gray-100 border"
                  title="Remove" onclick="return confirm('Remove {{ $link->mcc }}-{{ $link->mnc }} ?');">
            {{ $link->mcc }}-{{ $link->mnc }} <span aria-hidden="true">✕</span>
          </button>
        </form>
      @empty
        <span class="text-gray-400">No MNCs</span>
      @endforelse
    </div>
  </div>

  <script>
  (function syncMccForAddForm(){
    const src = document.getElementById('nf_mcc_display');
    const sel = document.getElementById('nf_selected_mcc');
    const clone = document.getElementById('nf_mcc_display_clone');
    const hidden = document.getElementById('nf_mcc_hidden');
    const btn = document.getElementById('nf_add_btn');
    function tick(){
      const m = sel && sel.value ? sel.value : (src ? src.value : '');
      if(clone) clone.value = m || '';
      if(hidden) hidden.value = m || '';
      if(btn) btn.disabled = !m;
    }
    tick();
    setInterval(tick, 250);
  })();
  </script>
</x-app-layout>
BLADE

############################################
# 3) API Controllers (search + mccs)
############################################
mkdir -p app/Http/Controllers/Api
cat > app/Http/Controllers/Api/CountrySearchController.php <<'PHP'
<?php
namespace App\Http\Controllers\Api;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;

class CountrySearchController extends Controller {
    public function __invoke(Request $request) {
        $q = trim((string)$request->query('q',''));
        $limit = (int)($request->query('limit', 20));
        if ($limit < 1 || $limit > 50) $limit = 20;

        if ($q === '') return response()->json([]);

        // ilike for Postgres (case-insensitive)
        $rows = DB::table('countries')
            ->select('id','name')
            ->where('name','ilike',"%{$q}%")
            ->orderBy('name')
            ->limit($limit)
            ->get();

        $ids = $rows->pluck('id')->all();
        $mccs = DB::table('country_mccs')
            ->select('country_id','mcc')
            ->whereIn('country_id',$ids)
            ->orderBy('mcc')
            ->get()
            ->groupBy('country_id')
            ->map(fn($g)=>$g->pluck('mcc')->values()->all());

        $out = [];
        foreach ($rows as $r) {
            $out[] = ['id'=>$r->id,'name'=>$r->name,'mccs'=>$mccs[$r->id] ?? []];
        }
        return response()->json($out);
    }
}
PHP

cat > app/Http/Controllers/Api/CountryMccsController.php <<'PHP'
<?php
namespace App\Http\Controllers\Api;

use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;
use App\Models\Country;

class CountryMccsController extends Controller {
    public function __invoke(Country $country) {
        $mccs = DB::table('country_mccs')
            ->where('country_id',$country->id)
            ->orderBy('mcc')
            ->pluck('mcc')->values()->all();
        return response()->json(['mccs'=>$mccs]);
    }
}
PHP

############################################
# 4) Strengthen NetworkMncController@store
############################################
F=app/Http/Controllers/NetworkMncController.php
if [ -f "$F" ]; then
  b "$F"
fi
cat > "$F" <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\Network;

class NetworkMncController extends Controller {
    public function store(Request $request, Network $network){
        $mcc = trim((string)$request->input('mcc',''));
        $mnc = trim((string)$request->input('mnc',''));
        $log = [];

        if (!preg_match('/^\d{3}$/', $mcc)) {
            return back()->with('error','MCC must be exactly 3 digits.');
        }
        if (!preg_match('/^\d{1,5}$/', $mnc)) {
            return back()->with('error','MNC must be 1-5 digits.');
        }

        // MCC must belong to network's country
        $allowed = DB::table('country_mccs')->where('country_id', $network->country_id)->pluck('mcc')->all();
        if (!in_array($mcc, $allowed, true)) {
            $log[] = "Rejected: MCC $mcc is not assigned to {$network->country->name}.";
            return back()->with('error', "MCC $mcc does not belong to this network's country.")->with('log',$log);
        }

        // Unique index (mcc,mnc) is global; block stealing from other network
        $existing = DB::table('network_mncs')->where('mcc',$mcc)->where('mnc',$mnc)->first();
        if ($existing) {
            if ((int)$existing->network_id === (int)$network->id) {
                return back()->with('status','Nothing to change. Already exists.');
            }
            $log[] = "Duplicate: $mcc-$mnc already linked to network_id={$existing->network_id}.";
            return back()->with('error','Duplicate MCC+MNC exists on another network.')->with('log',$log);
        }

        DB::table('network_mncs')->insert([
            'network_id' => $network->id,
            'mcc'        => $mcc,
            'mnc'        => $mnc,
            'mcc_mnc'    => $mcc.$mnc,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return back()->with('status','MNC added.');
    }

    public function destroy(Network $network, string $mcc, string $mnc){
        DB::table('network_mncs')->where('network_id',$network->id)->where('mcc',$mcc)->where('mnc',$mnc)->delete();
        return back()->with('status','MNC removed.');
    }
}
PHP

############################################
# 5) Append API routes (auth)
############################################
R=routes/web.php
b "$R"
cat >> "$R" <<'PHP'

// === API (auth) for country search + mccs ===
Route::middleware(['auth'])->prefix('api')->group(function () {
    Route::get('/countries/search', \App\Http\Controllers\Api\CountrySearchController::class);
    Route::get('/countries/{country}/mccs', \App\Http\Controllers\Api\CountryMccsController::class);
});
PHP

############################################
# 6) Cache warm
############################################
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l resources/views/networks/_form.blade.php
  php -l resources/views/networks/create.blade.php
  php -l resources/views/networks/edit.blade.php
  php -l app/Http/Controllers/Api/CountrySearchController.php
  php -l app/Http/Controllers/Api/CountryMccsController.php
  php -l app/Http/Controllers/NetworkMncController.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  php artisan route:list | grep -E "api/countries|networks\.mncs" -n || true
'
echo "==> Step5c done."
