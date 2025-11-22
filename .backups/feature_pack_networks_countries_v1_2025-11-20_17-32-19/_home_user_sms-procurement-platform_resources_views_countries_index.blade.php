<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Countries</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
    <div class="overflow-x-auto rounded-lg border bg-white">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
            <th class="px-4 py-3">Country</th>
            <th class="px-4 py-3">ISO2</th>
            <th class="px-4 py-3">MCCs</th>
            <th class="px-4 py-3">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100 text-sm">
          @forelse($countries as $c)
            <tr>
              <td class="px-4 py-2">{{ $c->name }}</td>
              <td class="px-4 py-2">{{ strtoupper($c->iso2 ?? '') }}</td>
              <td class="px-4 py-2">
                {{ $c->mccs ? $c->mccs->pluck('mcc')->unique()->implode(', ') : '' }}
              </td>
              <td class="px-4 py-2 text-right">
                <a href="{{ route('countries.edit', $c) }}" class="text-indigo-600 hover:underline mr-3">Edit</a>
                <form action="{{ route('countries.destroy', $c) }}" method="POST" class="inline">
                  @csrf @method('DELETE')
                  <button type="submit" onclick="return confirm('Delete this country?')" class="text-red-600 hover:underline">Delete</button>
                </form>
              </td>
            </tr>
          @empty
            <tr><td colspan="4" class="px-4 py-6 text-center text-gray-500">No results.</td></tr>
          @endforelse
        </tbody>
      </table>
    </div>

    <div class="flex items-center justify-between">
      <div class="text-sm text-gray-600">
        @if($countries->total())
          Showing {{ $countries->firstItem() }}–{{ $countries->lastItem() }} of {{ $countries->total() }} results
        @else
          Showing 0 of 0 results
        @endif
      </div>
      <div class="text-sm">
        {{ $countries->onEachSide(1)->links() }}
      </div>
    </div>
  </div>
</x-app-layout>
