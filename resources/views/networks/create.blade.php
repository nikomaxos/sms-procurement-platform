<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">New Network</h2></x-slot>
  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    @include('partials.flash_log')
    <form method="POST" action="{{ route('networks.store') }}" class="bg-white rounded shadow p-4">
      @include('networks._form', ['network' => $network])
      <div class="mt-4">
        <button class="rounded bg-blue-600 text-white px-4 py-2" type="submit">Create</button>
        <a class="ml-3 text-gray-600 hover:underline" href="{{ route('networks.index') }}">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
