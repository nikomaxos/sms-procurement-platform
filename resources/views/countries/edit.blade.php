<x-app-layout>
    @include('partials.flash_log')
@include("components.flash-log")
@include("components.flash-log")
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Country — {{ $country->name }}</h2>
  </x-slot>

  <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('success')) <div class="mb-4 p-3 rounded bg-green-50 text-green-700">{{ session('success') }}</div> @endif
    @if (session('warning')) <div class="mb-4 p-3 rounded bg-yellow-50 text-yellow-700">{{ session('warning') }}</div> @endif
    @if (session('error'))   <div class="mb-4 p-3 rounded bg-red-50 text-red-700">{{ session('error') }}</div> @endif
    @if (session('info'))    <div class="mb-4 p-3 rounded bg-blue-50 text-blue-700">{{ session('info') }}</div> @endif

    {{-- Basic fields --}}
    <form method="POST" action="{{ route('countries.update', $country->id) }}" class="bg-white rounded-lg shadow p-6 mb-8">
      @csrf @method('PUT')
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <label class="block">
          <span class="text-sm text-gray-600">Name</span>
          <input name="name" value="{{ old('name', $country->name) }}" class="mt-1 w-full border rounded p-2" required>
          @error('name')<div class="text-red-600 text-sm mt-1">{{ $message }}</div>@enderror
        </label>
        <label class="block">
          <span class="text-sm text-gray-600">ISO2</span>
          <input name="iso2" value="{{ old('iso2', $country->iso2 ?? '') }}" class="mt-1 w-full border rounded p-2" maxlength="2">
          @error('iso2')<div class="text-red-600 text-sm mt-1">{{ $message }}</div>@enderror
        </label>
      </div>
      <div class="mt-4">
        <button class="px-4 py-2 rounded bg-indigo-600 text-white hover:bg-indigo-700">Save</button>
        <a href="{{ route('countries.index') }}" class="ml-2 text-gray-600 hover:underline">Back</a>
      </div>
    </form>

    {{-- MCC management --}}
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="font-semibold mb-3">Mobile Country Codes (MCCs)</h3>

      @php
        // Expecting $mccs as array; if not present, compute safely
        $mccs = (isset($mccs) && is_array($mccs)) ? $mccs
              : \Illuminate\Support\Facades\DB::table('country_mccs')->where('country_id', $country->id)->orderBy('mcc')->pluck('mcc')->toArray();
      @endphp

      <div class="flex flex-wrap gap-2 mb-4">
        @forelse($mccs as $m)
          <span class="inline-flex items-center gap-2 bg-gray-100 rounded px-2 py-1 text-sm">
            <span class="font-mono">{{ $m }}</span>
            <form method="POST" action="{{ route('countries.mccs.destroy', [$country->id, $m]) }}" onsubmit="return confirm('Remove MCC {{ $m }}?')">
              @csrf @method('DELETE')
              <button class="text-red-600 hover:text-red-800" title="Remove">&times;</button>
            </form>
          </span>
        @empty
          <span class="text-gray-500">No MCCs yet.</span>
        @endforelse
      </div>

      <form method="POST" action="{{ route('countries.mccs.store', $country->id) }}" class="flex items-end gap-3">
        @csrf
        <label>
          <span class="block text-sm text-gray-600">Add MCC</span>
          <input name="mcc" maxlength="3" class="border rounded p-2 w-24" placeholder="202" value="{{ old('mcc') }}">
        </label>
        <button class="px-3 py-2 rounded bg-gray-800 text-white hover:bg-black">Add</button>
      </form>
      @error('mcc')<div class="text-red-600 text-sm mt-2">{{ $message }}</div>@enderror
    </div>
  </div>
</x-app-layout>

{{-- ===== Step8: Μεταφορά MCC σε άλλη χώρα (Admin) ===== --}}
<div class="mt-8 p-4 border rounded bg-white">
  <h3 class="font-semibold mb-2">Μεταφορά MCC σε άλλη χώρα</h3>

  @if (session('error'))
    <div class="bg-red-100 text-red-800 text-sm p-2 rounded mb-2">{{ session('error') }}</div>
  @endif
  @if (session('status'))
    <div class="bg-green-100 text-green-800 text-sm p-2 rounded mb-2">{{ session('status') }}</div>
  @endif
  @if (session('log'))
    <details open class="mb-3">
      <summary class="cursor-pointer font-medium">Λεπτομέρειες</summary>
      <ul class="list-disc pl-5">
        @foreach((array) session('log') as $line)
          <li>{{ $line }}</li>
        @endforeach
      </ul>
    </details>
  @endif

  @php
    $mccRows = \Illuminate\Support\Facades\DB::table('country_mccs')->where('country_id',$country->id)->orderBy('mcc')->get();
    $allCountries = \App\Models\Country::orderBy('name')->get();
  @endphp

  <form method="POST" action="{{ route('countries.mccs.reassign', ['country'=>$country->id]) }}" class="grid grid-cols-1 md:grid-cols-3 gap-3">
    @csrf
    <div>
      <label class="block text-sm font-medium mb-1">MCC προς μεταφορά</label>
      <select name="mcc" class="border rounded w-full p-2" required>
        <option value="" disabled selected>— επίλεξε MCC —</option>
        @foreach($mccRows as $r)
          <option value="{{ $r->mcc }}">{{ $r->mcc }}</option>
        @endforeach
      </select>
    </div>
    <div>
      <label class="block text-sm font-medium mb-1">Νέα χώρα</label>
      <select name="target_country_id" class="border rounded w-full p-2" required>
        <option value="" disabled selected>— επίλεξε χώρα —</option>
        @foreach($allCountries as $c)
          <option value="{{ $c->id }}">{{ $c->name }} ({{ $c->id }})</option>
        @endforeach
      </select>
    </div>
    <div class="flex items-end">
      <button class="px-3 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">Μεταφορά</button>
    </div>
  </form>
</div>
