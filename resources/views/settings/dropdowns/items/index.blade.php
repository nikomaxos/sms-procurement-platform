<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">
      Drop Down: {{ $menu->title }} — Items
    </h2>
  </x-slot>

  <div class="max-w-4xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-700 px-3 py-2">
        {{ session('status') }}
      </div>
    @endif

    <form method="POST" action="{{ route('settings.dropdowns.items.store', $menu) }}" class="mb-6 flex gap-2">
      @csrf
      <input name="label" class="border rounded px-3 py-2 w-full" placeholder="New item label..." required>
      <button class="rounded bg-blue-600 text-white px-4 py-2 hover:bg-blue-700">Add</button>
    </form>

    <div class="mb-2 text-sm text-gray-600">
      Drag items to reorder. Changes save automatically.
    </div>

    <ul id="sortable-list" class="bg-white border rounded divide-y">
      @foreach ($items as $item)
        <li class="flex items-center justify-between gap-3 px-3 py-2"
            data-id="{{ $item->id }}" draggable="true">
          <div class="flex items-center gap-2">
            <span class="cursor-grab select-none" aria-hidden="true">⋮⋮</span>
            <span>{{ $item->label }}</span>
          </div>
          <div class="flex items-center gap-2">
            <a href="{{ route('settings.dropdowns.items.edit', [$menu, $item]) }}"
               class="text-sm px-2 py-1 border rounded hover:bg-gray-50">Edit</a>
            <form method="POST" action="{{ route('settings.dropdowns.items.destroy', [$menu, $item]) }}"
                  onsubmit="return confirm('Delete this item?')">
              @csrf @method('DELETE')
              <button class="text-sm px-2 py-1 border rounded hover:bg-gray-50">Delete</button>
            </form>
          </div>
        </li>
      @endforeach
    </ul>

    <div id="save-status" class="mt-3 hidden text-sm"></div>

    <div class="mt-8">
      <a href="{{ route('settings.dropdowns.index') }}" class="text-sm text-blue-700 hover:underline">← Back to all menus</a>
    </div>
  </div>

  <script src="{{ asset('js/dnd-reorder.js') }}" defer></script>
</x-app-layout>
