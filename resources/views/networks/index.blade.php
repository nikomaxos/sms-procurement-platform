<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2></x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <form method="GET" class="flex items-center gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Search name…" class="rounded border px-3 py-2">
        <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC…" class="rounded border px-3 py-2">
        <input name="mnc" value="{{ request('mnc') }}" placeholder="MNC…" class="rounded border px-3 py-2">
        <input name="mcc_mnc" value="{{ request('mcc_mnc') }}" placeholder="MCC-MNC…" class="rounded border px-3 py-2">
        <input name="country" value="{{ request('country') }}" placeholder="Country…" class="rounded border px-3 py-2">
        <select name="per" class="rounded border px-2 py-2">
          @foreach([20,50,100,1000] as $opt)<option value="{{ $opt }}" @selected((int)request('per',20)===$opt)>{{ $opt }}</option>@endforeach
        </select>
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      </form>

      @if (\Illuminate\Support\Facades\Route::has('carriers.import'))
      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-2">
        @csrf
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Update from source</button>
        <input type="hidden" name="fresh" value="1">
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700" onclick="return confirm('Full refresh?')">Fresh import</button>
      </form>
      @endif

      <a href="{{ route('networks.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Network</a>
    </div>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">MCC-MNC</th>
            <th class="px-3 py-2 text-left">MCC</th>
            <th class="px-3 py-2 text-left">MNC</th>
            <th class="px-3 py-2 text-left">Network</th>
            <th class="px-3 py-2 text-left">Created</th>
            <th class="px-3 py-2 text-left">Updated</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($networks as $n)
          <tr class="border-t">
            <td class="px-3 py-2">{{ optional($n->country)->name ?? $n->country_name }}</td>
            <td class="px-3 py-2 font-mono">{{ $n->mcc_mnc }}</td>
            <td class="px-3 py-2">{{ $n->mcc }}</td>
            <td class="px-3 py-2">{{ $n->mnc }}</td>
            <td class="px-3 py-2">{{ $n->name }}</td>
            <td class="px-3 py-2">{{ optional($n->created_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2">{{ optional($n->updated_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2 text-right">
              <a href="{{ route('networks.edit',$n) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
              <form method="POST" action="{{ route('networks.destroy',$n) }}" class="inline-block" onsubmit="return confirm('Delete network?')">
                @csrf @method('DELETE')
                <button class="rounded px-3 py-2 bg-red-600 text-white hover:bg-red-700">Delete</button>
              </form>
            </td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $networks->appends(request()->all())->links() }}</div>
  </div>
</x-app-layout>
