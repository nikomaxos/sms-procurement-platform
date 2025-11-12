<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">
      Edit Item — {{ $menu->title }}
    </h2>
  </x-slot>

  <div class="py-6 max-w-xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="rounded-lg border bg-white p-6">
      <form method="POST" action="{{ route('settings.dropdowns.items.update', [$menu, $item]) }}" class="space-y-4">
        @csrf @method('PUT')
        <div>
          <label class="block text-sm font-medium text-gray-700">Label</label>
          <input name="label" value="{{ old('label', $item->label) }}" class="mt-1 w-full rounded border px-3 py-2" required maxlength="255">
          @error('label')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
        </div>
        <div class="flex items-center gap-2">
          <a href="{{ route('settings.dropdowns.items.index', $menu) }}" class="rounded border px-4 py-2 text-gray-700 hover:bg-gray-50">Back</a>
          <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        </div>
      </form>
    </div>
  </div>
</x-app-layout>
