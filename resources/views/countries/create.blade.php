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
