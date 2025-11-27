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
            ->with('mccs')
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
                        class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:ring-offset-1"
                    >
                        Apply filters
                    </button>
                    <a
                        href="{{ route('countries.index') }}"
                        class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
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
                        <th class="px-4 py-3">
                            MCCs
                        </th>
                        <th class="px-4 py-3">
                            Notes
                        </th>
                        <th class="px-4 py-3 text-right">
                            Actions
                        </th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-200">
                    @forelse ($countries as $country)
                        <tr class="text-sm">
                            <td class="px-4 py-2 whitespace-nowrap">
                                {{ $country->name }}
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap">
                                {{ $country->iso2 }}
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap">
                                @forelse ($country->mccs as $mcc)
                                    <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-gray-100 text-xs font-medium text-gray-800 mr-1">
                                        {{ $mcc->mcc }}
                                    </span>
                                @empty
                                    <span class="text-xs text-gray-400">—</span>
                                @endforelse
                            </td>
                            <td class="px-4 py-2 align-top text-sm text-gray-700">
                                @php
                                    $notes = $country->meta_notes ?? '';
                                @endphp
                                @if ($notes !== '')
                                    {{ \Illuminate\Support\Str::limit($notes, 80) }}
                                @else
                                    <span class="text-xs text-gray-400">—</span>
                                @endif
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-xs text-right">
                                <a
                                    href="{{ route('countries.edit', $country->id) }}"
                                    class="inline-flex items-center px-2 py-1 border border-gray-300 rounded-md bg-white text-gray-700 hover:bg-gray-50 mr-1"
                                >
                                    Edit
                                </a>

                                <form
                                    method="POST"
                                    action="{{ route('countries.destroy', $country->id) }}"
                                    class="inline"
                                    onsubmit="return confirm('Delete this country?');"
                                >
                                    @csrf
                                    @method('DELETE')
                                    <button
                                        type="submit"
                                        class="inline-flex items-center px-2 py-1 border border-red-300 rounded-md bg-red-50 text-red-700 hover:bg-red-100"
                                    >
                                        Delete
                                    </button>
                                </form>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="px-4 py-4 text-center text-sm text-gray-500">
                                No countries found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        {{-- Pagination + per-page selector at the bottom --}}
        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3 mt-3">
            <div>
                {{ $countries->links() }}
            </div>
            <div class="flex items-center gap-2 text-xs">
                <span class="text-gray-600">Results per page:</span>
                <select
                    id="countries_per_page_select"
                    class="rounded-md border-gray-300 text-xs shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                >
                    @foreach ([10, 25, 50, 100, 200] as $size)
                        <option value="{{ $size }}" @selected($perPage === $size)>{{ $size }}</option>
                    @endforeach
                </select>
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const perSel = document.getElementById('countries_per_page_select');
            const perHidden = document.getElementById('countries_per_page');
            const form = document.getElementById('countries-filter-form');

            if (perSel && perHidden && form) {
                perSel.addEventListener('change', function () {
                    perHidden.value = this.value;
                    form.submit();
                });
            }
        });
    </script>
</x-app-layout>
