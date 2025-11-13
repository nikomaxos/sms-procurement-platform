<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Countries</h2></x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <form method="GET" class="flex items-center gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Search name/ISO2…" class="rounded border px-3 py-2">
        <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC…" class="rounded border px-3 py-2">
        <select name="per" class="rounded border px-2 py-2">
          @foreach([20,50,100,1000] as $opt)<option value="{{ $opt }}" @selected((int)request('per',20)===$opt)>{{ $opt }}</option>@endforeach
        </select>
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      </form>

      {{-- Update only (no Fresh here) --}}
      @if (\Illuminate\Support\Facades\Route::has('carriers.import'))
      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-2">
        @csrf
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Update from source</button>
      </form>
      @endif

      <a href="{{ route('countries.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Country</a>
    </div>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">ISO2</th>
            <th class="px-3 py-2 text-left">MCCs</th>
            <th class="px-3 py-2 text-left">Created</th>
            <th class="px-3 py-2 text-left">Updated</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($countries as $c)
          <tr class="border-t">
            <td class="px-3 py-2">{{ $c->name }}</td>
            <td class="px-3 py-2">{{ $c->iso2 }}</td>
            <td class="px-3 py-2">
              @foreach(($c->mccs ?? []) as $m)
                <span class="inline-block rounded bg-gray-100 px-2 py-0.5 mr-1">{{ $m->mcc }}</span>
              @endforeach
            </td>
            <td class="px-3 py-2">{{ optional($c->created_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2">{{ optional($c->updated_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2 text-right">
              <a href="{{ route('countries.edit',$c) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
              <form method="POST" action="{{ route('countries.destroy',$c) }}" class="inline-block" onsubmit="return confirm('Delete country?')">
                @csrf @method('DELETE')
                <button class="rounded px-3 py-2 bg-red-600 text-white hover:bg-red-700">Delete</button>
              </form>
            </td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $countries->appends(request()->all())->links() }}</div>
  </div>
</x-app-layout>
