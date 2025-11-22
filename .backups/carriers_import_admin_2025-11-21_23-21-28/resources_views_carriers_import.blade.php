@php
    if (! auth()->check() || auth()->user()->usertype !== 'admin') {
        abort(403);
    }
@endphp

@extends('layouts.app')

@section('content')
<div class="max-w-3xl mx-auto p-6">
  <h1 class="text-2xl font-semibold mb-4">Carriers Import</h1>

  @if ($errors->any())
    <div class="mb-4 rounded border border-red-300 bg-red-50 p-3 text-red-800">
      <ul class="list-disc ms-5">
        @foreach ($errors->all() as $error)
          <li>{{ $error }}</li>
        @endforeach
      </ul>
    </div>
  @endif

  @if (session('error'))
    <div class="mb-4 rounded border border-red-300 bg-red-50 p-3 text-red-800">
      {{ session('error') }}
    </div>
  @endif

  @if (session('status'))
    <div class="mb-4 rounded border border-green-300 bg-green-50 p-3 text-green-800">
      {{ session('status') }}
    </div>
  @endif

  @php($summary = session('summary'))
  @if ($summary)
    <div class="mb-6 rounded border p-4 bg-white">
      <div class="font-medium mb-2">Summary</div>
      <dl class="grid grid-cols-2 gap-2 text-sm">
        <div><dt class="text-gray-500">Source</dt><dd class="font-medium">{{ $summary['source'] ?? 'auto' }}</dd></div>
        <div><dt class="text-gray-500">Fresh</dt><dd class="font-medium">{{ !empty($summary['fresh']) ? 'Yes' : 'No' }}</dd></div>
        <div><dt class="text-gray-500">Countries created</dt><dd class="font-medium">{{ $summary['createdCountries'] ?? 0 }}</dd></div>
        <div><dt class="text-gray-500">Networks created</dt><dd class="font-medium">{{ $summary['createdNetworks'] ?? 0 }}</dd></div>
        <div><dt class="text-gray-500">MNC links created</dt><dd class="font-medium">{{ $summary['createdMncs'] ?? 0 }}</dd></div>
        <div class="col-span-2"><dt class="text-gray-500">Message</dt><dd class="font-medium">{{ $summary['msg'] ?? '' }}</dd></div>
      </dl>
      <div class="mt-3 text-sm">
        <a class="underline text-blue-700" href="{{ route('countries.index') }}">Countries</a>
        &nbsp;·&nbsp;
        <a class="underline text-blue-700" href="{{ route('networks.index') }}">Networks</a>
      </div>
    </div>
  @endif

  <form method="POST" action="{{ route('carriers.import') }}" class="rounded border p-4 bg-white">
    @csrf

    <div class="mb-4">
      <label for="source" class="block text-sm font-medium mb-1">Data source</label>
      <select id="source" name="source" class="w-full border rounded p-2">
        <option value="auto" {{ old('source','auto')==='auto' ? 'selected' : '' }}>Auto (try remote, fallback local)</option>
        <option value="itu"  {{ old('source')==='itu' ? 'selected' : '' }}>Remote JSON (onomondo/ITU)</option>
        <option value="local" {{ old('source')==='local' ? 'selected' : '' }}>Local bundled fallback</option>
      </select>
      <p class="text-xs text-gray-500 mt-1">Auto fetches remote JSON; if unreachable, it uses the local bundled table.</p>
    </div>

    <div class="mb-4">
      <label class="inline-flex items-center gap-2">
        <input type="checkbox" name="fresh" value="1" {{ old('fresh') ? 'checked' : '' }}>
        <span class="text-sm font-medium">Clear existing MCC/MNC links first (“fresh”)</span>
      </label>
      <p class="text-xs text-gray-500 ms-6">
        This clears <code>country_mccs</code> and <code>network_mncs</code> only (countries/networks are kept).
      </p>
    </div>

    <div class="mb-6">
      <label class="inline-flex items-center gap-2">
        <input type="checkbox" name="fresh_confirm" value="1" {{ old('fresh_confirm') ? 'checked' : '' }}>
        <span class="text-sm">I understand the clearing step. (Required if “fresh” is ticked.)</span>
      </label>
    </div>

    <button type="submit" class="px-4 py-2 rounded bg-blue-600 text-white font-medium">
      Run import
    </button>
    <p class="text-xs text-gray-500 mt-2">If you click twice quickly, the action is locked for 60s to avoid duplicates.</p>
  </form>
</div>
@endsection
