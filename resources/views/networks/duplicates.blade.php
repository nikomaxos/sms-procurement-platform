<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Network Duplicates</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-8">
    @if (session('error'))
      <div class="p-3 rounded bg-red-100 text-red-800">{{ session('error') }}</div>
    @endif
    @if (session('status'))
      <div class="p-3 rounded bg-green-100 text-green-800">{{ session('status') }}</div>
    @endif
    @if (session('log'))
      <pre class="p-3 rounded bg-gray-100 text-xs overflow-auto">{{ json_encode(session('log'), JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE) }}</pre>
    @endif

    <div class="space-y-6">
      <h3 class="text-lg font-semibold">1) Duplicates by MCC+MNC</h3>
      @forelse ($dupByPair as $grp)
        @php $nets = json_decode($grp->nets ?? '[]', true) ?: []; @endphp
        <div class="border rounded p-3 bg-white">
          <div class="mb-2">
            <span class="font-mono text-sm px-2 py-1 bg-gray-100 rounded">MCC {{ $grp->mcc }} / MNC {{ $grp->mnc }}</span>
            <span class="ml-2 text-sm text-gray-500">({{ $grp->c }} entries)</span>
          </div>

          <form method="POST" action="{{ route('networks.duplicates.merge') }}" class="space-y-2">
            @csrf
            <input type="hidden" name="reason" value="merge-by-mcc-mnc {{ $grp->mcc }}-{{ $grp->mnc }}">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
              @foreach ($nets as $i => $n)
                <label class="flex items-center gap-2 border rounded p-2">
                  <input type="radio" name="target_id" value="{{ $n['id'] }}" {{ $i===0 ? 'checked' : '' }}>
                  <input type="checkbox" name="source_ids[]" value="{{ $n['id'] }}" {{ $i!==0 ? 'checked' : '' }}>
                  <span class="text-sm">
                    <span class="font-semibold">{{ $n['name'] }}</span>
                    <span class="text-gray-500">— {{ $n['id'] }}</span>
                    <span class="ml-1 text-gray-400">[{{ $n['country'] ?? '' }}]</span>
                  </span>
                </label>
              @endforeach
            </div>
            <div class="text-right">
              <button class="px-3 py-1 rounded bg-blue-600 text-white">Merge into selected</button>
            </div>
          </form>
        </div>
      @empty
        <div class="text-sm text-gray-500">No duplicates by MCC/MNC detected.</div>
      @endforelse
    </div>

    <div class="space-y-6">
      <h3 class="text-lg font-semibold">2) Duplicates by Country + Name</h3>
      @forelse ($dupByName as $grp)
        @php $nets = json_decode($grp->nets ?? '[]', true) ?: []; @endphp
        <div class="border rounded p-3 bg-white">
          <div class="mb-2">
            <span class="font-mono text-sm px-2 py-1 bg-gray-100 rounded">{{ $grp->country }}</span>
            <span class="ml-2 text-sm text-gray-500">name: “{{ $grp->lname }}” ({{ $grp->c }} entries)</span>
          </div>

          <form method="POST" action="{{ route('networks.duplicates.merge') }}" class="space-y-2">
            @csrf
            <input type="hidden" name="reason" value="merge-by-name country={{ $grp->country }} name={{ $grp->lname }}">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
              @foreach ($nets as $i => $n)
                <label class="flex items-center gap-2 border rounded p-2">
                  <input type="radio" name="target_id" value="{{ $n['id'] }}" {{ $i===0 ? 'checked' : '' }}>
                  <input type="checkbox" name="source_ids[]" value="{{ $n['id'] }}" {{ $i!==0 ? 'checked' : '' }}>
                  <span class="text-sm">
                    <span class="font-semibold">{{ $n['name'] }}</span>
                    <span class="text-gray-500">— {{ $n['id'] }}</span>
                  </span>
                </label>
              @endforeach
            </div>
            <div class="text-right">
              <button class="px-3 py-1 rounded bg-blue-600 text-white">Merge into selected</button>
            </div>
          </form>
        </div>
      @empty
        <div class="text-sm text-gray-500">No duplicates by Country+Name detected.</div>
      @endforelse
    </div>
  </div>
</x-app-layout>
