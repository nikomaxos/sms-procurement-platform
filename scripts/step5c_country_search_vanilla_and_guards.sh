#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"; b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step5c: VanillaJS country search + MCC readonly + server guards"

############################################
# 1) networks/_form.blade.php (χωρίς Alpine)
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
        <div class="mt-2">
            <div id="nf_mcc_chips" class="flex flex-wrap gap-1"></div>
        </div>
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
  const $$ = (sel, root=document) => Array.from(root.querySelectorAll(sel));
  const root = document.getElementById('netform');
  if(!root) return;

  const inCountryId   = $('#nf_country_id', root);
  const inCountryName = $('#nf_country_search', root);
  const boxResults    = $('#nf_results', root);
  const inSelMcc      = $('#nf_selected_mcc', root);
  const mccDisplay    = $('#nf_mcc_display', root);
  const mccChips      = $('#nf_mcc_chips', root);

  let results = [];
  let closeTimer = null;

  function showResults(list){
    boxResults.innerHTML = '';
    if(!list || !list.length){ boxResults.classList.add('hidden'); return; }
    list.forEach(item=>{
      const div = document.createElement('div');
      div.className = 'px-3 py-2 hover:bg-gray-50 cursor-pointer';
      div.textContent = item.name + (item.mccs && item.mccs.length ? '  (MCC: '+item.mccs.join(', ')+')' : '');
      div.addEventListener('click', ()=>{
        selectCountry(item);
      });
      boxResults.appendChild(div);
    });
    boxResults.classList.remove('hidden');
  }

  async function fetchSearch(q){
    try{
      const r = await fetch(`/api/countries/search?q=${encodeURIComponent(q)}&limit=20`);
      if(!r.ok) return showResults([]);
      results = await r.json();
      showResults(results);
    }catch(e){ showResults([]); }
  }

  async function fetchMccs(countryId){
    try{
      const r = await fetch(`/api/countries/${countryId}/mccs`);
      if(!r.ok) return [];
      const j = await r.json();
      return Array.isArray(j.mccs) ? j.mccs : [];
    }catch(e){ return []; }
  }

  function renderMccs(mccs){
    mccChips.innerHTML = '';
    if(!mccs.length){
      mccDisplay.value = '';
      inSelMcc.value = '';
      return;
    }
    // Pick selected or default to first
    if(!inSelMcc.value || !mccs.includes(inSelMcc.value)) inSelMcc.value = mccs[0];
    mccDisplay.value = inSelMcc.value;
    mccs.forEach(m=>{
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'inline-block px-2 py-1 text-xs rounded border ' + (m===inSelMcc.value ? 'bg-gray-800 text-white' : 'bg-gray-100');
      btn.textContent = m;
      btn.addEventListener('click', ()=>{
        inSelMcc.value = m;
        mccDisplay.value = m;
        renderMccs(mccs); // re-render to reflect active state
      });
      mccChips.appendChild(btn);
    });
  }

  async function selectCountry(item){
    inCountryId.value = item.id;
    inCountryName.value = item.name;
    boxResults.classList.add('hidden');
    const mccs = item.mccs && item.mccs.length ? item.mccs : await fetchMccs(item.id);
    renderMccs(mccs);
  }

  // Live search handlers
  inCountryName.addEventListener('input', (e)=>{
    const q = e.target.value.trim();
    if(!q){ results = []; showResults([]); return; }
    fetchSearch(q);
  });

  inCountryName.addEventListener('focus', ()=>{
    if(results.length) boxResults.classList.remove('hidden');
  });

  document.addEventListener('click', (e)=>{
    if(!root.contains(e.target)) boxResults.classList.add('hidden');
  });

  inCountryName.addEventListener('keydown', (e)=>{
    if(e.key === 'Escape') boxResults.classList.add('hidden');
  });

  // INIT (prefill on edit)
  (async function init(){
    const cid = inCountryId.value;
    if(cid){
      // Prefetch MCCs and set display
      const mccs = await fetchMccs(cid);
      renderMccs(mccs);
    }else{
      renderMccs([]);
    }
  })();
})();
</script>
BLADE

############################################
# 2) networks/create & edit wrappers (απλά κρατάμε το include)
############################################
F=resources/views/networks/create.blade.php
b "$F"
cat > "$F" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">New Network</h2>
  </x-slot>
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
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2>
  </x-slot>
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
        <div>
          <button class="rounded bg-gray-800 text-white px-3 py-2" type="submit" id="nf_add_btn" disabled>Add</button>
        </div>
      </form>

      @php $links = $network->mncs()->orderBy('mcc')->orderBy('mnc')->get(); @endphp
      @forelse ($links as $link)
        <form method="POST" class="inline-block mr-2 mb-2"
              action="{{ route('networks.mncs.destroy', [$network->id, $link->mcc, $link->mnc]) }}">
          @csrf @method('DELETE')
          <button class="inline-flex items-center gap-2 px-2 py-1 text-xs rounded bg-gray-100 border"
                  title="Remove"
                  onclick="return confirm('Remove {{ $link->mcc }}-{{ $link->mnc }} ?');">
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
    setInterval(tick, 250); // απλός συγχρονισμός χωρίς Alpine/React
  })();
  </script>
</x-app-layout>
BLADE

############################################
# 3) Server-side guard: NetworkMncController@store
############################################
F=app/Http/Controllers/NetworkMncController.php
b "$F"
php -r '
$F="app/Http/Controllers/NetworkMncController.php";
$txt=file_get_contents($F);
$txt=preg_replace("/public function store\\s*\\([\\s\\S]*?\\)\\s*\\{[\\s\\S]*?\\n\\}/",
"public function store(Request \$request, \\App\\Models\\Network \$network){\n".
"    \$mcc = trim((string)\$request->input(\"mcc\",\"\"));\n".
"    \$mnc = trim((string)\$request->input(\"mnc\",\"\"));\n".
"    \$log = [];\n".
"    if(!preg_match(\"/^\\\\d{3}$/\", \$mcc)){ return back()->with(\"error\",\"MCC must be exactly 3 digits.\"); }\n".
"    if(!preg_match(\"/^\\\\d{1,5}$/\", \$mnc)){ return back()->with(\"error\",\"MNC must be 1-5 digits.\"); }\n".
"    // allow only MCCs that belong to network->country_id\n".
"    \$allowed = \\DB::table(\"country_mccs\")->where(\"country_id\", \$network->country_id)->pluck(\"mcc\")->all();\n".
"    if(!in_array(\$mcc, \$allowed, true)){\n".
"        \$log[] = \"Rejected MNC because MCC \".\$mcc.\" does not belong to this network's country.\";\n".
"        return back()->with(\"error\",\"MCC \" . \$mcc . \" does not belong to the selected country.\")->with(\"log\",\$log);\n".
"    }\n".
"    // upsert-like behavior, friendly duplicate handling\n".
"    try{\n".
"        \\DB::table(\"network_mncs\")->updateOrInsert([\n".
"            \"mcc\"=>\$mcc, \"mnc\"=>\$mnc\n".
"        ],[\n".
"            \"network_id\"=>\$network->id,\n".
"            \"mcc_mnc\"=>\$mcc.\$mnc,\n".
"            \"updated_at\"=>now(),\n".
"            \"created_at\"=>now(),\n".
"        ]);\n".
"    }catch(\\Illuminate\\Database\\QueryException \$e){\n".
"        \$log[] = \"Duplicate or constraint error: \".\$e->getMessage();\n".
"        return back()->with(\"error\",\"Duplicate MCC+MNC for this network.\")->with(\"log\",\$log);\n".
"    }\n".
"    return back()->with(\"status\",\"MNC added.\");\n".
"}", 1);
file_put_contents($F,$txt);
'

############################################
# 4) Cache warm
############################################
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l resources/views/networks/_form.blade.php
  php -l resources/views/networks/create.blade.php
  php -l resources/views/networks/edit.blade.php
  php -l app/Http/Controllers/NetworkMncController.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
'
echo "==> Step5c done."
