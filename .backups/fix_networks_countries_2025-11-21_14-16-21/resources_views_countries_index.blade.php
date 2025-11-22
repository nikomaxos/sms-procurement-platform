<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Countries
        </h2>
    </x-slot>

    @php
        $request   = request();
        $name      = trim((string) $request->input('name', ''));
        $iso2      = trim((string) $request->input('iso2', ''));
        $sort      = $request->input('sort', 'name');
        $direction = strtolower((string) $request->input('direction', 'asc')) === 'desc' ? 'desc' : 'asc';
        $perPage   = (int) $request->input('per_page', 50);

        if ($perPage <= 0 || $perPage > 200) {
            $perPage = 50;
        }

        $query = \App\Models\Country::query()
            ->from('countries as c')
            ->leftJoin('country_meta as cm', 'cm.country_id', '=', 'c.id')
            ->select('c.*', 'cm.notes as meta_notes');

        if ($name !== '') {
            $query->whereRaw('LOWER(c.name) LIKE ?', ['%' . strtolower($name) . '%']);
        }

        if ($iso2 !== '') {
            $query->whereRaw('LOWER(c.iso2) LIKE ?', ['%' . strtolower($iso2) . '%']);
        }

        if ($sort === 'iso2') {
            $query->orderBy('c.iso2', $direction)->orderBy('c.name', 'asc');
        } else {
            $query->orderBy('c.name', $direction)->orderBy('c.iso2', 'asc');
            $sort = 'name';
        }

        $countries = $query->paginate($perPage)->appends($request->query());

        $nameNextDir = ($sort === 'name' && $direction === 'asc') ? 'desc' : 'asc';
        $iso2NextDir = ($sort === 'iso2' && $direction === 'asc') ? 'desc' : 'asc';
    @endphp

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
        @includeIf('partials.flash_log')

        {{-- Filters – one row: name + ISO2 --}}
        <form method="GET" action="{{ route('countries.index') }}" id="countries-filter-form">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 items-end">
                <div>
                    <label for="filter_country_name" class="block text-sm font-medium text-gray-700">
                        Name
                    </label>
                    <input
                        type="text"
                        id="filter_country_name"
                        name="name"
                        value="{{ $name }}"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        placeholder="Search by country name"
                    >
                </div>

                <div>
                    <label for="filter_country_iso2" class="block text-sm font-medium text-gray-700">
                        ISO2
                    </label>
                    <input
                        type="text"
                        id="filter_country_iso2"
                        name="iso2"
                        value="{{ strtoupper($iso2) }}"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm uppercase"
                        placeholder="EG, GR, US"
                    >
                </div>

                <div class="flex gap-2 justify-start md:justify-end">
                    <button
                        type="submit"
                        class="inline-flex items-center px-4 py-2 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                    >
                        Apply filters
                    </button>
                    <a
                        href="{{ route('countries.index') }}"
                        class="inline-flex items-center px-3 py-2 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                    >
                        Reset
                    </a>
                </div>
            </div>

            <input type="hidden" name="sort" id="countries_sort" value="{{ $sort }}">
            <input type="hidden" name="direction" id="countries_direction" value="{{ $direction }}">
            <input type="hidden" name="per_page" id="countries_per_page" value="{{ $perPage }}">
        </form>

        <div class="overflow-x-auto rounded-lg border bg-white">
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                        <th class="px-4 py-3">
                            <a href="{{ route('countries.index', array_merge(request()->except('page'), ['sort' => 'name', 'direction' => $nameNextDir])) }}"
                               class="inline-flex items-center gap-1">
                                Country
                                @if ($sort === 'name')
                                    <span class="text-[10px] text-gray-500">
                                        {{ $direction === 'asc' ? '▲' : '▼' }}
                                    </span>
                                @endif
                            </a>
                        </th>
                        <th class="px-4 py-3">
                            <a href="{{ route('countries.index', array_merge(request()->except('page'), ['sort' => 'iso2', 'direction' => $iso2NextDir])) }}"
                               class="inline-flex items-center gap-1">
                                ISO2
                                @if ($sort === 'iso2')
                                    <span class="text-[10px] text-gray-500">
                                        {{ $direction === 'asc' ? '▲' : '▼' }}
                                    </span>
                                @endif
                            </a>
                        </th>
                        <th class="px-4 py-3">Notes</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white text-sm">
                    @forelse($countries as $country)
                        @php $notes = $country->meta_notes ?? null; @endphp
                        <tr class="hover:bg-gray-50">
                            <td class="px-4 py-3 text-gray-900">
                                {{ $country->name }}
                            </td>
                            <td class="px-4 py-3 text-gray-900">
                                {{ $country->iso2 }}
                            </td>
                            <td class="px-4 py-3 text-gray-900 max-w-xs">
                                @if (! empty($notes))
                                    <span title="{{ $notes }}">
                                        {{ \Illuminate\Support\Str::limit($notes, 80) }}
                                    </span>
                                @else
                                    <span class="text-xs text-gray-400">—</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="3" class="px-4 py-6 text-center text-gray-500">
                                No results.
                            </td>
                        </tr>
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
            <div class="flex items-center gap-3 text-sm">
                <div class="flex items-center gap-1">
                    <span>Per page:</span>
                    <select
                        class="block rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        onchange="document.getElementById('countries_per_page').value=this.value; document.getElementById('countries-filter-form').submit();"
                    >
                        @foreach ([25, 50, 100, 200] as $size)
                            <option value="{{ $size }}" @selected($perPage === $size)>{{ $size }}</option>
                        @endforeach
                    </select>
                </div>
                <div>
                    {{ $countries->onEachSide(1)->links() }}
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
