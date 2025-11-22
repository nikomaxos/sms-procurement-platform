<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Networks
        </h2>
    </x-slot>

    @php
        $request       = request();

        $q             = trim((string) $request->input('q', ''));
        $countryId     = $request->input('country_id');
        $countryLabel  = trim((string) $request->input('country_label', ''));
        $nonOperational= $request->input('non_operational'); // '', '1', '0'
        $sort          = $request->input('sort', 'country');
        $direction     = strtolower((string) $request->input('direction', 'asc')) === 'desc' ? 'desc' : 'asc';
        $perPage       = (int) $request->input('per_page', 25);

        if ($perPage <= 0 || $perPage > 200) {
            $perPage = 25;
        }

        $countries = \App\Models\Country::orderBy('name')->get();

        if ($countryLabel === '' && $countryId) {
            $c = $countries->firstWhere('id', (int) $countryId);
            if ($c) {
                $countryLabel = trim($c->name . ' (' . $c->iso2 . ')');
            }
        }

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

        $query = \App\Models\Network::query()
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
            $query->orderBy('networks.name', $direction)
                  ->orderBy('country_name', 'asc');
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
                            @foreach ($countries as $countryOption)
                                @php
                                    $label = trim($countryOption->name . ' (' . $countryOption->iso2 . ')');
                                @endphp
                                <li
                                    class="px-3 py-1 cursor-pointer hover:bg-indigo-50"
                                    data-id="{{ $countryOption->id }}"
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
                </div>

                <div class="mt-3 flex flex-wrap gap-2 justify-start md:justify-end">
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
                </div>

                <input type="hidden" name="sort" id="networks_sort" value="{{ $sort }}">
                <input type="hidden" name="direction" id="networks_direction" value="{{ $direction }}">
                <input type="hidden" name="per_page" id="networks_per_page" value="{{ $perPage }}">
            </form>

            {{-- Results table --}}
            <div class="overflow-x-auto rounded-lg border bg-white">
                <table class="min-w-full divide-y divide-gray-200">
                    <thead class="bg-gray-50">
                        <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                            <th class="px-4 py-3">
                                <a href="{{ route('networks.index', array_merge(request()->except('page'), ['sort' => 'country', 'direction' => $countryNextDir])) }}"
                                   class="inline-flex items-center gap-1">
                                    Country
                                    @if ($sort === 'country')
                                        <span class="text-[10px] text-gray-500">
                                            {{ $direction === 'asc' ? '▲' : '▼' }}
                                        </span>
                                    @endif
                                </a>
                            </th>
                            <th class="px-4 py-3">
                                <a href="{{ route('networks.index', array_merge(request()->except('page'), ['sort' => 'name', 'direction' => $nameNextDir])) }}"
                                   class="inline-flex items-center gap-1">
                                    Name
                                    @if ($sort === 'name')
                                        <span class="text-[10px] text-gray-500">
                                            {{ $direction === 'asc' ? '▲' : '▼' }}
                                        </span>
                                    @endif
                                </a>
                            </th>
                            <th class="px-4 py-3">
                                MNCs
                            </th>
                            <th class="px-4 py-3">
                                Non-operational
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
                        @forelse ($networks as $network)
                            @php
                                $countryName = $network->country_name ?? optional($network->country)->name;
                                $countryIso2 = $network->country_iso2 ?? optional($network->country)->iso2;
                                $nonOp = (bool) ($network->non_operational ?? false);
                            @endphp
                            <tr class="text-sm">
                                <td class="px-4 py-2 whitespace-nowrap">
                                    @if ($countryName)
                                        {{ $countryName }}
                                        @if ($countryIso2)
                                            <span class="text-xs text-gray-400">({{ $countryIso2 }})</span>
                                        @endif
                                    @else
                                        <span class="text-xs text-gray-400">—</span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    {{ $network->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    @forelse ($network->mncs as $mnc)
                                        @php
                                            $mcc = str_pad((string) $mnc->mcc, 3, '0', STR_PAD_LEFT);
                                            $mncCode = str_pad((string) $mnc->mnc, 3, '0', STR_PAD_LEFT);
                                        @endphp
                                        <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-gray-100 text-xs font-medium text-gray-800 mr-1">
                                            {{ $mcc }}/{{ $mncCode }}
                                        </span>
                                    @empty
                                        <span class="text-xs text-gray-400">—</span>
                                    @endforelse
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    @if ($nonOp)
                                        <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-red-100 text-xs font-semibold text-red-800">
                                            Non-operational
                                        </span>
                                    @else
                                        <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-green-100 text-xs font-semibold text-green-800">
                                            Operational
                                        </span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 align-top text-sm text-gray-700">
                                    @php
                                        $notes = $network->meta_notes ?? '';
                                    @endphp
                                    @if ($notes !== '')
                                        {{ \Illuminate\Support\Str::limit($notes, 80) }}
                                    @else
                                        <span class="text-xs text-gray-400">—</span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-xs text-right">
                                    <a
                                        href="{{ route('networks.edit', $network->id) }}"
                                        class="inline-flex items-center px-2 py-1 border border-gray-300 rounded-md bg-white text-gray-700 hover:bg-gray-50 mr-1"
                                    >
                                        Edit
                                    </a>

                                    <form
                                        method="POST"
                                        action="{{ route('networks.destroy', $network->id) }}"
                                        class="inline"
                                        onsubmit="return confirm('Delete this network?');"
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
                                <td colspan="6" class="px-4 py-4 text-center text-sm text-gray-500">
                                    No networks found.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{-- Pagination + per-page selector at the bottom --}}
            <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3 mt-3">
                <div>
                    {{ $networks->links() }}
                </div>
                <div class="flex items-center gap-2 text-xs">
                    <span class="text-gray-600">Results per page:</span>
                    <select
                        id="networks_per_page_select"
                        class="rounded-md border-gray-300 text-xs shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                    >
                        @foreach ([10, 25, 50, 100, 200] as $size)
                            <option value="{{ $size }}" @selected($perPage === $size)>{{ $size }}</option>
                        @endforeach
                    </select>
                </div>
            </div>
        </div>
    </div>

    <style>
        /* Strong visual highlight for the active suggestion when using arrow keys */
        #country_suggestions li.bg-indigo-100 {
            background-color: #4f46e5; /* approx. Tailwind indigo-600 */
            color: #ffffff;
        }
    </style>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const input  = document.getElementById('filter_country_name');
            const hidden = document.getElementById('filter_country_id');
            const box    = document.getElementById('country_suggestions');
            const perSel = document.getElementById('networks_per_page_select');
            const perHidden = document.getElementById('networks_per_page');
            const form   = document.getElementById('networks-filter-form');

            if (perSel && perHidden && form) {
                perSel.addEventListener('change', function () {
                    perHidden.value = this.value;
                    form.submit();
                });
            }

            if (!input || !box || !hidden) {
                return;
            }

            let allItems = Array.from(box.querySelectorAll('li'));
            let visibleItems = allItems.slice();
            let activeIndex = -1;

            function closeBox() {
                box.classList.add('hidden');
                activeIndex = -1;
                visibleItems.forEach(li => li.classList.remove('bg-indigo-100'));
            }

            function openBox() {
                if (visibleItems.length) {
                    box.classList.remove('hidden');
                }
            }

            function setActive(index) {
                visibleItems.forEach(li => li.classList.remove('bg-indigo-100'));
                activeIndex = index;
                if (index >= 0 && index < visibleItems.length) {
                    const li = visibleItems[index];
                    li.classList.add('bg-indigo-100');
                    li.scrollIntoView({ block: 'nearest' });
                }
            }

            function filterList(term) {
                const q = term.trim().toLowerCase();
                visibleItems = [];
                allItems.forEach(li => {
                    const text = li.dataset.label.toLowerCase();
                    if (!q || text.includes(q)) {
                        li.classList.remove('hidden');
                        visibleItems.push(li);
                    } else {
                        li.classList.add('hidden');
                    }
                });
                if (!visibleItems.length) {
                    closeBox();
                } else {
                    openBox();
                }
            }

            allItems.forEach(li => {
                li.addEventListener('mousedown', function (e) {
                    e.preventDefault(); // keep focus on input
                    const id = this.dataset.id;
                    const label = this.dataset.label;
                    input.value = label;
                    hidden.value = id;
                    closeBox();
                });
            });

            input.addEventListener('input', function () {
                const val = this.value;
                hidden.value = '';
                filterList(val);
                if (val.trim() === '') {
                    closeBox();
                } else {
                    openBox();
                }
            });

            input.addEventListener('focus', function () {
                if (this.value.trim() !== '') {
                    filterList(this.value);
                }
                openBox();
            });

            input.addEventListener('keydown', function (e) {
                if (box.classList.contains('hidden')) {
                    if (e.key === 'ArrowDown' && this.value.trim() !== '') {
                        filterList(this.value);
                        openBox();
                        if (visibleItems.length) {
                            setActive(0);
                        }
                        e.preventDefault();
                    }
                    return;
                }

                if (e.key === 'ArrowDown') {
                    if (visibleItems.length) {
                        const next = activeIndex < visibleItems.length - 1 ? activeIndex + 1 : 0;
                        setActive(next);
                        e.preventDefault();
                    }
                } else if (e.key === 'ArrowUp') {
                    if (visibleItems.length) {
                        const prev = activeIndex > 0 ? activeIndex - 1 : visibleItems.length - 1;
                        setActive(prev);
                        e.preventDefault();
                    }
                } else if (e.key === 'Enter') {
                    if (activeIndex >= 0 && activeIndex < visibleItems.length) {
                        const li = visibleItems[activeIndex];
                        input.value = li.dataset.label;
                        hidden.value = li.dataset.id;
                        closeBox();
                        e.preventDefault();
                        form.submit();
                    }
                } else if (e.key === 'Escape') {
                    closeBox();
                }
            });

            document.addEventListener('click', function (e) {
                if (!box.contains(e.target) && e.target !== input) {
                    closeBox();
                }
            });
        });
    </script>
</x-app-layout>
