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
