<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Import Carriers (ITU)</h2></x-slot>
  <div class="py-6 max-w-xl mx-auto px-4 sm:px-6 lg:px-8">
    @if ($errors->any())
      <div class="mb-4 rounded bg-red-50 text-red-700 px-4 py-2">{{ $errors->first() }}</div>
    @endif
    @if (session('status'))
      <div class="mb-4 rounded bg-green-50 text-green-700 px-4 py-2">{{ session('status') }}</div>
    @endif
    <form method="POST" action="{{ route('carriers.import') }}" class="space-y-3 bg-white p-4 border rounded">
      @csrf
      <label class="block text-sm text-gray-700">Source</label>
      <select name="source" class="rounded border px-3 py-2">
        <option value="itu" selected>ITU JSON (github raw)</option>
      </select>
      <label class="inline-flex items-center gap-2"><input type="checkbox" name="fresh" value="1"> <span>Fresh (truncate links)</span></label>
      <div class="flex items-center gap-3">
        <button class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Run Import</button>
        <a href="{{ route('networks.index') }}" class="rounded border px-4 py-2 bg-white hover:bg-gray-50">Back</a>
      </div>
    </form>
  </div>
</x-app-layout>
