<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Networks
        </h2>
    </x-slot>

    @php
        use App\Models\Network;
        use App\Models\Country;
        use Illuminate\Support\Str;

        $request = request();

        $q              = trim((string) $request->input('q', ''));
        $countryId      = $request->input('country_id');
        $countryLabel   = trim((string) $request->input('country_label', ''));
        $nonOperational = $request->input('non_operational'); // '', '1', '0'
        $sort           = $request->input('sort', 'country');
        $direction      = strtolower((string) $request->input('direction', 'asc')) === 'desc' ? 'desc' : 'asc';
        $perPage        = (int) $request->input('per_page', 25);

        if ($perPage <= 0 || $perPage > 200) {
            $perPage = 25;
        }

        // Countries for typeahead dropdown
        $countries = Country::orderBy('name')->get();

        if ($countryLabel === '' && $countryId) {
            $c = $countries->firstWhere('id', (int) $countryId);
            if ($c) {
                $countryLabel = trim($c->name . ' (' . $c->iso2 . ')');
            }
        }

        // Map view filters into existing scopeFilter()
        $filters = [];
        if ($q !== '') {
            $filters['q'] = $q;
        }
        if ($countryId) {
            $filters['country_id'] = $countryId;
        }
        if ($request->filled('mcc')) {
            $filters['mcc'] = $request->input('mcc');
        }
        if ($request->filled('mnc')) {
            $filters['mnc'] = $request->input('mnc');
        }

        $query = Network::query()
            ->with(['mncs', 'country'])
            ->leftJoin('countries as c', 'networks.country_id', '=', 'c.id')
            ->leftJoin('network_meta as nm', 'nm.network_id', '=', 'networks.id')
            ->select(
                'networks.*',
                'c.name as country_name',
                'c.iso2 as country_iso2',
                'nm.non_operational',
                'nm.notes as meta_notes'
            )
            ->filter($filters);

        if ($nonOperational === '1') {
            $query->where('nm.non_operational', true);
        } elseif ($nonOperational === '0') {
            $query->where(function ($q2) {
                $q2->where('nm.non_operational', false)
                   ->orWhereNull('nm.non_operational');
            });
        }

        if ($sort === 'name') {
            $query->orderBy('networks.name', $direction);
        } else {
            $query->orderBy('country_name', $direction)
                  ->orderBy('networks.name', 'asc');
            $sort = 'country';
        }

        $networks = $query->paginate($perPage)->appends($request->query());

        $countryNextDir = ($sort === 'country' && $direction === 'asc') ? 'desc' : 'asc';
        $nameNextDir    = ($sort === 'name' && $direction === 'asc') ? 'desc' : 'asc';
    @endphp

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        @includeIf('partials.flash_log')

        <div class="bg-white shadow-sm sm:rounded-lg p-4 space-y-4">

            {{-- Filters in one row: q, country, non-operational --}}
            <form method="GET" action="{{ route('networks.index') }}" id="networks-filter-form">
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4 items-end">
                    {{-- Search by name (q) --}}
                    <div class="md:col-span-2">
                        <label for="filter_q" class="block text-sm font-medium text-gray-700">
                            Search name
                        </label>
                        <input
                            type="text"
                            id="filter_q"
                            name="q"
                            value="{{ $q }}"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            placeholder="e.g. Cosmote"
                        >
                    </div>

                    {{-- Country filter with typeahead + keyboard navigation --}}
                    <div class="relative">
                        <label for="filter_country_name" class="block text-sm font-medium text-gray-700">
                            Country
                        </label>

                        <input type="hidden" name="country_id" id="filter_country_id" value="{{ $countryId }}">

                        <input
                            type="text"
                            id="filter_country_name"
                            name="country_label"
                            autocomplete="off"
                            value="{{ $countryLabel }}"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            placeholder="Start typing country name..."
                        >

                        <ul
                            id="country_suggestions"
                            class="absolute z-20 mt-1 w-full bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto text-sm hidden"
                        >
                            @foreach ($countries as $country)
                                @php
                                    $label = trim($country->name . ' (' . $country->iso2 . ')');
                                @endphp
                                <li
                                    class="px-3 py-1 cursor-pointer hover:bg-indigo-50"
                                    data-id="{{ $country->id }}"
                                    data-label="{{ $label }}"
                                >
                                    {{ $label }}
                                </li>
                            @endforeach
                        </ul>
                    </div>

                    {{-- Non-operational filter --}}
                    <div>
                        <label for="filter_non_operational" class="block text-sm font-medium text-gray-700">
                            Non-operational
                        </label>
                        <select
                            id="filter_non_operational"
                            name="non_operational"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        >
                            <option value="">All</option>
                            <option value="1" @selected($nonOperational === '1')>Only non-operational</option>
                            <option value="0" @selected($nonOperational === '0')>Only operational</option>
                        </select>
                    </div>

                    {{-- Actions: apply/reset + Export CSV [Inference: CSV export route param] --}}
                    <div class="flex gap-2 justify-start md:justify-end mt-2 md:mt-0">
                        <button
                            type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                        >
                            Apply filters
                        </button>
                        <a
                            href="{{ route('networks.index') }}"
                            class="inline-flex items-center px-3 py-2 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                        >
                            Reset
                        </a>
                        <a
                            class="inline-flex items-center px-3 py-2 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                            href="{{ route('networks.index', array_merge(request()->query(), ['export' => 'csv'])) }}"
                        >
                            Export CSV
                        </a>
                    </div>
                </div>

                {{-- Hidden sort / per-page fields --}}
                <input type="hidden" name="sort" id="networks_sort" value="{{ $sort }}">
                <input type="hidden" name="direction" id="networks_direction" value="{{ $direction }}">
                <input type="hidden" name="per_page" id="networks_per_page" value="{{ $perPage }}">
            </form>

            {{-- Table --}}
            <div class="mt-4 overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                    <thead class="bg-gray-50">
                        <tr>
                            {{-- Country (sortable, first column) --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                <a href="{{ route('networks.index', array_merge(request()->except('page'), ['sort' => 'country', 'direction' => $countryNextDir])) }}"
                                   class="inline-flex items-center gap-1">
                                    Country
                                    @if ($sort === 'country')
                                        <span class="text-xs text-gray-500">
                                            {{ $direction === 'asc' ? '▲' : '▼' }}
                                        </span>
                                    @endif
                                </a>
                            </th>

                            {{-- Name (sortable, second column) --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                <a href="{{ route('networks.index', array_merge(request()->except('page'), ['sort' => 'name', 'direction' => $nameNextDir])) }}"
                                   class="inline-flex items-center gap-1">
                                    Name
                                    @if ($sort === 'name')
                                        <span class="text-xs text-gray-500">
                                            {{ $direction === 'asc' ? '▲' : '▼' }}
                                        </span>
                                    @endif
                                </a>
                            </th>

                            {{-- MCC chips --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                MCCs
                            </th>

                            {{-- MNC chips --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                MNCs
                            </th>

                            {{-- Non-operational --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                Non-operational
                            </th>

                            {{-- Notes --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                Notes
                            </th>

                            {{-- Actions --}}
                            <th scope="col" class="px-3 py-2 text-right font-medium text-gray-700 uppercase tracking-wider">
                                Actions
                            </th>
                        </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                        @forelse ($networks as $network)
                            @php
                                $mncsAll = $network->mncs ?? collect();
                                $mncs = $mncsAll->where('marked_for_deletion', false);
                                $mccList = $mncs->pluck('mcc')->filter()->unique()->values();
                                $mncList = $mncs->pluck('mnc')->filter()->unique()->values();
                                $notes   = $network->meta_notes ?? null;
                            @endphp
                            <tr>
                                {{-- Country --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $network->country_name ?? optional($network->country)->name ?? '—' }}
                                    @php $iso = $network->country_iso2 ?? optional($network->country)->iso2; @endphp
                                    @if (! empty($iso))
                                        <span class="text-xs text-gray-500">
                                            ({{ $iso }})
                                        </span>
                                    @endif
                                </td>

                                {{-- Name --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $network->name }}
                                </td>

                                {{-- MCC chips --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm">
                                    @forelse ($mccList as $mcc)
                                        <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-800 mr-1">
                                            {{ $mcc }}
                                        </span>
                                    @empty
                                        <span class="text-xs text-gray-400">—</span>
                                    @endforelse
                                </td>

                                {{-- MNC chips --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm">
                                    @forelse ($mncList as $mnc)
                                        <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-800 mr-1">
                                            {{ $mnc }}
                                        </span>
                                    @empty
                                        <span class="text-xs text-gray-400">—</span>
                                    @endforelse
                                </td>

                                {{-- Non-operational --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm">
                                    @if ($network->non_operational ?? false)
                                        <span class="inline-flex items-center rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800">
                                            Yes
                                        </span>
                                    @else
                                        <span class="inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800">
                                            No
                                        </span>
                                    @endif
                                </td>

                                {{-- Notes --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm text-gray-900 max-w-xs">
                                    @if (! empty($notes))
                                        <span title="{{ $notes }}">
                                            {{ Str::limit($notes, 80) }}
                                        </span>
                                    @else
                                        <span class="text-xs text-gray-400">—</span>
                                    @endif
                                </td>

                                {{-- Actions placeholder --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm text-right text-gray-500">
                                    {{-- Hook show/edit here if needed --}}
                                    …
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" class="px-3 py-4 text-center text-sm text-gray-500">
                                    No networks found for the current filters.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{-- Bottom paginator + results-per-page selector --}}
            <div class="mt-4 flex flex-col md:flex-row md:items-center md:justify-between gap-3">
                <div class="text-sm text-gray-600">
                    @if ($networks->total() > 0)
                        Showing
                        <span class="font-medium">{{ $networks->firstItem() }}</span>
                        –
                        <span class="font-medium">{{ $networks->lastItem() }}</span>
                        of
                        <span class="font-medium">{{ $networks->total() }}</span>
                        networks
                    @else
                        No networks to display.
                    @endif
                </div>

                <div class="flex items-center gap-2">
                    <span class="text-sm text-gray-600">Per page:</span>
                    <select
                        class="block rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        onchange="document.getElementById('networks_per_page').value=this.value; document.getElementById('networks-filter-form').submit();"
                    >
                        @foreach ([10, 25, 50, 100, 200] as $size)
                            <option value="{{ $size }}" @selected($perPage === $size)>{{ $size }}</option>
                        @endforeach
                    </select>
                </div>

                <div>
                    {{ $networks->onEachSide(1)->links() }}
                </div>
            </div>
        </div>
    </div>

    {{-- JS for country typeahead + keyboard navigation --}}
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const input = document.getElementById('filter_country_name');
            const hiddenId = document.getElementById('filter_country_id');
            const list = document.getElementById('country_suggestions');
            if (!input || !hiddenId || !list) return;

            const allItems = Array.from(list.querySelectorAll('li'));
            let visibleItems = allItems.slice();
            let activeIndex = -1;

            function closeList() {
                list.classList.add('hidden');
                activeIndex = -1;
                allItems.forEach(li => li.classList.remove('bg-indigo-100'));
            }

            function openList() {
                if (visibleItems.length > 0) {
                    list.classList.remove('hidden');
                }
            }

            function updateVisible() {
                const query = input.value.toLowerCase();
                visibleItems = [];
                allItems.forEach(li => {
                    const label = (li.dataset.label || '').toLowerCase();
                    const match = label.includes(query);
                    li.style.display = match ? '' : 'none';
                    if (match) visibleItems.push(li);
                });
                if (query === '') {
                    allItems.forEach(li => { li.style.display = ''; });
                    visibleItems = allItems.slice();
                }
                activeIndex = visibleItems.length ? 0 : -1;
                allItems.forEach(li => li.classList.remove('bg-indigo-100'));
                if (activeIndex >= 0 && visibleItems[activeIndex]) {
                    visibleItems[activeIndex].classList.add('bg-indigo-100');
                }
            }

            function selectItem(li) {
                hiddenId.value = li.dataset.id || '';
                input.value = li.dataset.label || '';
                closeList();
            }

            input.addEventListener('input', function () {
                updateVisible();
                openList();
            });

            input.addEventListener('keydown', function (e) {
                if (list.classList.contains('hidden')) {
                    if (e.key === 'ArrowDown') {
                        updateVisible();
                        openList();
                        e.preventDefault();
                    }
                    return;
                }

                if (e.key === 'ArrowDown') {
                    if (visibleItems.length === 0) return;
                    activeIndex = (activeIndex + 1) % visibleItems.length;
                    allItems.forEach(li => li.classList.remove('bg-indigo-100'));
                    visibleItems[activeIndex].classList.add('bg-indigo-100');
                    e.preventDefault();
                } else if (e.key === 'ArrowUp') {
                    if (visibleItems.length === 0) return;
                    activeIndex = (activeIndex - 1 + visibleItems.length) % visibleItems.length;
                    allItems.forEach(li => li.classList.remove('bg-indigo-100'));
                    visibleItems[activeIndex].classList.add('bg-indigo-100');
                    e.preventDefault();
                } else if (e.key === 'Enter') {
                    if (activeIndex >= 0 && visibleItems[activeIndex]) {
                        selectItem(visibleItems[activeIndex]);
                        e.preventDefault();
                    }
                } else if (e.key === 'Escape') {
                    closeList();
                    e.preventDefault();
                }
            });

            allItems.forEach(li => {
                li.addEventListener('mousedown', function (e) {
                    e.preventDefault();
                    selectItem(li);
                });
            });

            document.addEventListener('click', function (e) {
                if (!list.contains(e.target) && e.target !== input) {
                    closeList();
                }
            });

            updateVisible();
        });
    </script>
</x-app-layout>
