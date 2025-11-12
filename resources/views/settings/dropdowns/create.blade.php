<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">New Drop Down Menu</h2>
  </x-slot>

  <div class="py-6 max-w-xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="rounded-lg border bg-white p-6">
      <form method="POST" action="{{ route('settings.dropdowns.store') }}" class="space-y-4">
        @csrf
        <div>
          <label class="block text-sm font-medium text-gray-700">Title</label>
          <input name="title" value="{{ old('title') }}" class="mt-1 w-full rounded border px-3 py-2" required maxlength="120">
          @error('title')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
        </div>
        <div class="flex items-center gap-2">
          <a href="{{ route('settings.dropdowns.index') }}" class="rounded border px-4 py-2 text-gray-700 hover:bg-gray-50">Cancel</a>
          <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Create</button>
        </div>
      </form>
    </div>
  </div>
</x-app-layout>
