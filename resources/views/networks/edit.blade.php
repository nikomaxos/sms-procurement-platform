<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2></x-slot>
  <div class="py-6 max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.update',$network) }}" class="space-y-4">
      @csrf @method('PUT')
      @include('networks._form')
      <div class="flex gap-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
