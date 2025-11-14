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
