<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @includeIf('partials.flash_log')

    <form method="GET" action="{{ route('networks.index') }}" class="bg-white rounded shadow p-4 mb-4">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-3 items-end">
        <div class="md:col-span-2">
          <label class="block text-sm font-medium mb-1">Search name</label>
          <input class="border rounded w-full p-2" type="text" name="q" value="{{ $filters['q'] ?? '' }}" placeholder="e.g. Cosmote">
        </div>

        <div>
          <label class="block text-sm font-medium mb-1">Country</label>
          <div class="relative">
            <input id="fi_country" class="border rounded w-full p-2" type="text" autocomplete="off"
                   placeholder="Type to search..."
                   value="{{ $filters['country_name'] ?? '' }}">
            <input type="hidden" name="country_id" id="fi_country_id" value="{{ $filters['country_id'] ?? '' }}">
            <div id="fi_results" class="hidden absolute z-10 mt-1 w-full bg-white border rounded shadow max-h-64 overflow-auto"></div>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium mb-1">Per page</label>
          <select class="border rounded w-full p-2" name="per_page">
            @foreach([20,50,100] as $n)
              <option value="{{ $n }}" @selected(($filters['per_page'] ?? 20)==$n)>{{ $n }}</option>
            @endforeach
          </select>
        </div>
      </div>

      <div class="mt-3 flex flex-wrap gap-2">
        <button class="rounded bg-blue-600 text-white px-4 py-2" type="submit">Filter</button>
        <a class="rounded bg-gray-100 px-4 py-2 border" href="{{ route('networks.index') }}">Clear</a>
        <a class="rounded bg-gray-800 text-white px-4 py-2"
           href="{{ route('networks.index', array_merge(request()->query(), ['export' => 'csv'])) }}">
           Export CSV
        </a>
      </div>
    </form>

    <div class="bg-white rounded shadow overflow-x-auto">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="text-left px-4 py-2">Name</th>
            <th class="text-left px-4 py-2">Country</th>
            <th class="text-left px-4 py-2">MCCs</th>
            <th class="text-left px-4 py-2">MNCs</th>
            <th class="text-left px-4 py-2">Actions</th>
          </tr>
        </thead>
        <tbody>
          @foreach ($networks as $n)
            <tr class="border-t">
              <td class="px-4 py-2">{{ $n->name }}</td>
              <td class="px-4 py-2">{{ $n->country->name ?? $n->country_id }}</td>
              <td class="px-4 py-2">
                @php $mccs = isset($mccsMap[$n->id]) ? explode(",", $mccsMap[$n->id]) : []; @endphp
                @forelse($mccs as $m)
                  <span class="inline-block text-xs bg-gray-100 border rounded px-2 py-0.5 mr-1 mb-1">{{ $m }}</span>
                @empty
                  <span class="text-gray-400">—</span>
                @endforelse
              </td>
              <td class="px-4 py-2">{{ $n->mncs_count }}</td>
              <td class="px-4 py-2">
                <a class="text-blue-700 hover:underline" href="{{ route('networks.edit', $n->id) }}">Edit</a>
              </td>
            </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $networks->links() }}</div>
  </div>

  <script>
  (function(){
    const root = document;
    const box = root.getElementById('fi_results');
    const input = root.getElementById('fi_country');
    const hidden = root.getElementById('fi_country_id');
    if(!input || !box) return;

    const show = (rows)=>{
      box.innerHTML = '';
      if(!rows || !rows.length){ box.classList.add('hidden'); return; }
      rows.forEach(r=>{
        const d = document.createElement('div');
        const mcc = (r.mccs && r.mccs.length) ? ` (MCC: ${r.mccs.join(', ')})` : '';
        d.textContent = r.name + mcc;
        d.className = 'px-3 py-2 hover:bg-gray-50 cursor-pointer';
        d.addEventListener('click', ()=>{
          input.value = r.name;
          hidden.value = r.id;
          box.classList.add('hidden');
        });
        box.appendChild(d);
      });
      box.classList.remove('hidden');
    };

    let last = [];
    async function search(q){
      try{
        const r = await fetch(`/api/countries/search?q=${encodeURIComponent(q)}&limit=20`);
        if(!r.ok){ box.classList.add('hidden'); return; }
        last = await r.json();
        show(last);
      }catch(_e){ box.classList.add('hidden'); }
    }

    input.addEventListener('input', e=>{
      const q = e.target.value.trim();
      if(!q){ box.classList.add('hidden'); hidden.value = ''; return; }
      search(q);
    });
    input.addEventListener('focus', ()=>{ if(last.length) box.classList.remove('hidden'); });
    document.addEventListener('click', e=>{ if(!box.contains(e.target) && e.target!==input) box.classList.add('hidden'); });
    input.addEventListener('keydown', e=>{ if(e.key==='Escape') box.classList.add('hidden'); });
  })();
  </script>
</x-app-layout>
