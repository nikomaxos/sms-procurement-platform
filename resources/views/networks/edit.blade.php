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
