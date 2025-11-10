<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">Known Hops</h2></x-slot>
    <div class="py-6">
      <div class="max-w-4xl mx-auto sm:px-6 lg:px-8">
        <x-alert />
        <div class="bg-white p-6 shadow sm:rounded-lg">
          <div class="flex justify-between mb-4">
            <div></div>
            <a href="{{ route('admin/known_hops.create') }}" class="px-4 py-2 bg-indigo-600 text-white rounded">New</a>
          </div>
          <table class="w-full text-left">
            <thead><tr class="border-b"><th class="py-2">Name</th><th>Slug</th><th class="text-right">Actions</th></tr></thead>
            <tbody>
              @foreach($items as $item)
              <tr class="border-b">
                <td class="py-2">{{ $item->name }}</td>
                <td>{{ $item->slug }}</td>
                <td class="text-right">
                  <a class="px-3 py-1 bg-gray-100 rounded" href="{{ route('admin/known_hops.edit', $item) }}">Edit</a>
                  <form method="POST" action="{{ route('admin/known_hops.destroy', $item) }}" class="inline" onsubmit="return confirm('Delete?')">
                    @csrf @method('DELETE')
                    <button class="px-3 py-1 bg-red-600 text-white rounded">Delete</button>
                  </form>
                </td>
              </tr>
              @endforeach
            </tbody>
          </table>
          <div class="mt-4">{{ $items->links() }}</div>
        </div>
      </div>
    </div>
</x-app-layout>
