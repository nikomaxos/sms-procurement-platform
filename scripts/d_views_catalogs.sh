#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p resources/views/{countries,networks}

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
        <input name="q" value="{{ request('q') }}" placeholder="Search countries or MCC…" class="rounded border px-3 py-2">
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
          @foreach ($countries as $c)
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
            <td class="px-3 py-2 text-right"><a href="{{ route('countries.edit',$c) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a></td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $countries->withQueryString()->links() }}</div>
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

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <form method="GET" class="flex items-center gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Search networks, MCC, MNC…" class="rounded border px-3 py-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      </form>
      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-2">
        @csrf
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Update from source</button>
        <input type="hidden" name="fresh" value="1">
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700" onclick="return confirm('Full refresh?')">Fresh import</button>
      </form>
      <a href="{{ route('networks.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Network</a>
    </div>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Name</th>
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
          @foreach ($networks as $n)
          <tr class="border-t">
            <td class="px-3 py-2">{{ $n->name }}</td>
            <td class="px-3 py-2">{{ $n->mcc }}</td>
            <td class="px-3 py-2">{{ $n->mnc }}</td>
            <td class="px-3 py-2">{{ $n->mcc_mnc }}</td>
            <td class="px-3 py-2">{{ optional($n->country)->name }}</td>
            <td class="px-3 py-2">{{ optional($n->created_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2">{{ optional($n->updated_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2 text-right"><a href="{{ route('networks.edit',$n) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a></td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $networks->withQueryString()->links() }}</div>
  </div>
</x-app-layout>
BLADE

# Network form + create/edit (define $network on create)
cat > resources/views/networks/_form.blade.php <<'BLADE'
@php /** @var \App\Models\Network|null $network */ @endphp
<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
  <div>
    <label class="block text-sm font-medium text-gray-700">Name</label>
    <input name="name" value="{{ old('name', $network->name ?? '') }}" class="mt-1 w-full rounded border px-3 py-2">
  </div>
  <div>
    <label class="block text-sm font-medium text-gray-700">MCC</label>
    <input name="mcc" value="{{ old('mcc', $network->mcc ?? '') }}" class="mt-1 w-full rounded border px-3 py-2">
  </div>
  <div>
    <label class="block text-sm font-medium text-gray-700">MNC</label>
    <input name="mnc" value="{{ old('mnc', $network->mnc ?? '') }}" class="mt-1 w-full rounded border px-3 py-2">
  </div>
  <div class="md:col-span-3">
    <label class="block text-sm font-medium text-gray-700">Country</label>
    <input name="country_lookup" id="country_lookup" placeholder="Type to search…" class="mt-1 w-full rounded border px-3 py-2" autocomplete="off" value="{{ old('country_lookup', optional($network->country ?? null)->name) }}">
    <input type="hidden" name="country_id" id="country_id" value="{{ old('country_id', $network->country_id ?? '') }}">
    <p class="text-xs text-gray-500 mt-1">Type to find & link a country.</p>
  </div>
</div>
<script>
document.addEventListener('DOMContentLoaded', () => {
  const inp = document.getElementById('country_lookup');
  const hid = document.getElementById('country_id');
  if (!inp) return;
  let t=null;
  inp.addEventListener('input', () => {
    clearTimeout(t);
    t=setTimeout(async () => {
      const q = inp.value.trim(); if (!q) return;
      const res = await fetch(`{{ url('/countries/lookup?q=') }}`+encodeURIComponent(q));
      const items = await res.json(); if (!Array.isArray(items) || !items.length) return;
      const pick = items[0]; inp.value = pick.name; hid.value = pick.id;
    }, 250);
  });
});
</script>
BLADE

cat > resources/views/networks/create.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Add Network</h2></x-slot>
  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.store') }}" class="space-y-6">
      @csrf
      @include('networks._form', ['network' => new \App\Models\Network()])
      <div class="flex gap-3">
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
  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.update', $network) }}" class="space-y-6">
      @csrf @method('PUT')
      @include('networks._form')
      <div class="flex gap-3">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

echo "Views written."
