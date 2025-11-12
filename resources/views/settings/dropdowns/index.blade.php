<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Drop Down Menus</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="mb-4">
      <a href="{{ route('settings.dropdowns.create') }}"
         class="inline-flex items-center rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 text-sm">
        + New Menu
      </a>
    </div>

    <div class="overflow-hidden rounded-lg border bg-white">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-2 text-left font-semibold text-gray-700">ID</th>
            <th class="px-4 py-2 text-left font-semibold text-gray-700">Title</th>
            <th class="px-4 py-2 text-left font-semibold text-gray-700">Items</th>
            <th class="px-4 py-2 text-right font-semibold text-gray-700">Actions</th>
          </tr>
        </thead>
        <tbody>
        @forelse($menus as $menu)
          <tr class="border-t">
            <td class="px-4 py-2 text-gray-800">{{ $menu->id }}</td>
            <td class="px-4 py-2 text-gray-800">{{ $menu->title }}</td>
            <td class="px-4 py-2 text-gray-800">{{ $menu->items_count }}</td>
            <td class="px-4 py-2">
              <div class="flex items-center gap-2 justify-end">
                <a href="{{ route('settings.dropdowns.items.index', $menu) }}"
                   class="rounded border px-3 py-1.5 text-gray-700 hover:bg-gray-50">Manage items</a>
                <a href="{{ route('settings.dropdowns.edit', $menu) }}"
                   class="rounded border px-3 py-1.5 text-gray-700 hover:bg-gray-50">Edit</a>
                <form method="POST" action="{{ route('settings.dropdowns.destroy', $menu) }}"
                      onsubmit="return confirm('Delete this menu (and its items)?');">
                  @csrf @method('DELETE')
                  <button class="rounded border px-3 py-1.5 text-red-600 hover:bg-red-50">Delete</button>
                </form>
              </div>
            </td>
          </tr>
        @empty
          <tr class="border-t">
            <td colspan="4" class="px-4 py-6 text-center text-gray-500">No menus yet. Create one.</td>
          </tr>
        @endforelse
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $menus->links() }}</div>
  </div>
</x-app-layout>
