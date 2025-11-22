<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Networks
        </h2>
    </x-slot>

    @php
        $request        = request();

        $q              = trim((string) $request->input('q', ''));
        $countryId      = $request->input('country_id');
        $countryLabel   = trim((string) $request->input('country_label', ''));
        $nonOperational = $request->input('non_operational'); // '', '1', '0'
        $mccmncRaw      = (string) $request->input('mccmnc', '');
        $mccmnc         = preg_replace('/\D+/', '', $mccmncRaw ?? '');
        $sort           = $request->input('sort', 'country');
        $direction      = strtolower((string) $request->input('direction', 'asc')) === 'desc' ? 'desc' : 'asc';
        $perPage        = (int) $request->input('per_page', 25);

        if ($perPage <= 0 || $perPage > 200) {
            $perPage = 25;
        }

        // Countries for typeahead dropdown
        $countries = \App\Models\Country::orderBy('name')->get();

        if ($countryLabel === '' && $countryId) {
            $c = $countries->firstWhere('id', (int) $countryId);
            if ($c) {
                $countryLabel = trim($c->name . ' (' . $c->iso2 . ')');
            }
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
            );

        if ($q !== '') {
            $query->whereRaw('LOWER(networks.name) LIKE ?', ['%' . strtolower($q) . '%']);
        }

        if ($countryId) {
            $query->where('networks.country_id', $countryId);
        }

        if ($nonOperational === '1') {
            $query->where('nm.non_operational', true);
        } elseif ($nonOperational === '0') {
            $query->where(function ($q2) {
                $q2->where('nm.non_operational', false)
                   ->orWhereNull('nm.non_operational');
            });
        }

        // MCCMNC "starts with" filter
        if ($mccmnc !== '') {
            $query->whereHas('mncs', function ($q2) use ($mccmnc) {
                $q2->whereRaw(
                    "(CAST(mcc AS TEXT) || LPAD(CASE WHEN CHAR_LENGTH(CAST(mnc AS TEXT)) = 3 AND LEFT(CAST(mnc AS TEXT), 1) = '0' THEN SUBSTRING(CAST(mnc AS TEXT) FROM 2) ELSE CAST(mnc AS TEXT) END, 2, '0')) LIKE ?",
                    [$mccmnc . '%']
                );
            });
        }

        if ($sort === 'name') {
            $query->orderBy('networks.name', $direction)->orderBy('country_name', 'asc');
        } else {
            $query->orderBy('country_name', $direction)->orderBy('networks.name', 'asc');
            $sort = 'country';
        }

        $networks = $query->paginate($perPage)->appends($request->query());

        $countryNextDir = ($sort === 'country' && $direction === 'asc') ? 'desc' : 'asc';
        $nameNextDir    = ($sort === 'name' && $direction === 'asc') ? 'desc' : 'asc';
    @endphp

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        @includeIf('partials.flash_log')

        <div class="bg-white shadow-sm sm:rounded-lg p-4 space-y-4">

            {{-- Filters – single row on desktop: q, country, mccmnc, non-operational, actions --}}
            <form method="GET" action="{{ route('networks.index') }}" id="networks-filter-form">
                <div class="grid grid-cols-1 md:grid-cols-5 gap-4 items-end">
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

                    {{-- Country filter with typeahead --}}
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

                    {{-- MCCMNC filter (starts-with) --}}
                    <div>
                        <label for="filter_mccmnc" class="block text-sm font-medium text-gray-700">
                            MCCMNC
                        </label>
                        <input
                            type="text"
                            id="filter_mccmnc"
                            name="mccmnc"
                            inputmode="numeric"
                            pattern="[0-9]*"
                            value="{{ $mccmnc }}"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            placeholder="Starts with… e.g. 202"
                        >
                    </div>

                    {{-- Non-operational filter (last) --}}
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

                    {{-- Actions --}}
                    <div class="flex gap-2 justify-start md:justify-end">
                        <button
                            type="submit"
                            class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:ring-offset-1"
                        >
                            Apply filters
                        </button>
                        <a
                            href="{{ route('networks.index') }}"
                            class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                        >
                            Reset
                        </a>
                    </div>
                </div>

                <input type="hidden" name="sort" id="networks_sort" value="{{ $sort }}">
                <input type="hidden" name="direction" id="networks_direction" value="{{ $direction }}">
                <input type="hidden" name="per_page" id="networks_per_page" value="{{ $perPage }}">
            </form>

            <div class="overflow-x-auto rounded-lg border">
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
                                    Network
                                    @if ($sort === 'name')
                                        <span class="text-[10px] text-gray-500">
                                            {{ $direction === 'asc' ? '▲' : '▼' }}
                                        </span>
                                    @endif
                                </a>
                            </th>
                            <th class="px-4 py-3">MCCs</th>
                            <th class="px-4 py-3">MNCs</th>
                            <th class="px-4 py-3">Non-operational</th>
                            <th class="px-4 py-3">Notes</th>
                            <th class="px-4 py-3 text-right">Actions</th>
                        </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                        @forelse ($networks as $network)
                            @php
                                $mncs = $network->mncs ?? collect();
                                $mccs = $mncs->pluck('mcc')->filter()->unique()->sort()->values();
                            @endphp
                            <tr>
                                <td class="px-4 py-2 text-sm text-gray-900">
                                    @if ($network->country)
                                        {{ $network->country_name ?? $network->country->name }}
                                        @if ($network->country_iso2 ?? $network->country->iso2)
                                            <span class="text-xs text-gray-500">
                                                ({{ $network->country_iso2 ?? $network->country->iso2 }})
                                            </span>
                                        @endif
                                    @else
                                        <span class="text-xs text-gray-400">—</span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 text-sm text-gray-900">
                                    {{ $network->name }}
                                </td>
                                <td class="px-4 py-2 text-sm">
                                    <div class="flex flex-wrap gap-1">
                                        @forelse ($mccs as $mcc)
                                            <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs text-gray-700 border border-gray-200">
                                                {{ str_pad((string) $mcc, 3, '0', STR_PAD_LEFT) }}
                                            </span>
                                        @empty
                                            <span class="text-xs text-gray-400">—</span>
                                        @endforelse
                                    </div>
                                </td>
                                <td class="px-4 py-2 text-sm">
                                    <div class="flex flex-wrap gap-1">
                                        @forelse ($mncs as $mnc)
                                            @php
                                                $mncVal = (string) $mnc->mnc;
                                                if (strlen($mncVal) === 3 && substr($mncVal, 0, 1) === '0') {
                                                    $mncVal = substr($mncVal, 1);
                                                }
                                                $mncDisplay = str_pad($mncVal, 2, '0', STR_PAD_LEFT);
                                            @endphp
                                            <span class="inline-flex items-center rounded-full bg-indigo-50 px-2 py-0.5 text-xs text-indigo-700 border border-indigo-200">
                                                {{ $mncDisplay }}
                                            </span>
                                        @empty
                                            <span class="text-xs text-gray-400">—</span>
                                        @endforelse
                                    </div>
                                </td>
                                <td class="px-4 py-2 text-sm">
                                    @if ($network->non_operational)
                                        <span class="inline-flex items-center rounded-full bg-red-50 px-2 py-0.5 text-xs font-medium text-red-700 border border-red-200">
                                            Non-operational
                                        </span>
                                    @else
                                        <span class="inline-flex items-center rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-700 border border-emerald-200">
                                            Operational
                                        </span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 text-sm text-gray-700">
                                    {{ $network->meta_notes ? \Illuminate\Support\Str::limit($network->meta_notes, 80) : '—' }}
                                </td>
                                <td class="px-4 py-2 text-sm text-right">
                                    <div class="inline-flex items-center gap-2">
                                        <a
                                            href="{{ route('networks.edit', $network) }}"
                                            class="inline-flex items-center rounded border border-gray-300 bg-white px-2 py-1 text-xs text-gray-700 hover:bg-gray-50"
                                        >
                                            Edit
                                        </a>
                                        <form method="POST" action="{{ route('networks.destroy', $network) }}" onsubmit="return confirm('Delete this network?');">
                                            @csrf
                                            @method('DELETE')
                                            <button
                                                type="submit"
                                                class="inline-flex items-center rounded border border-red-300 bg-white px-2 py-1 text-xs text-red-700 hover:bg-red-50"
                                            >
                                                Delete
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" class="px-4 py-6 text-center text-gray-500 text-sm">
                                    No networks found.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div class="mt-4 flex flex-col md:flex-row items-center justify-between gap-3">
                <div class="text-xs text-gray-500">
                    @if ($networks->total())
                        Showing {{ $networks->firstItem() }}–{{ $networks->lastItem() }} of {{ $networks->total() }} results
                    @else
                        No results.
                    @endif
                </div>

                <div class="flex items-center gap-4">
                    <form method="GET" action="{{ route('networks.index') }}" class="flex items-center gap-2 text-xs">
                        <input type="hidden" name="q" value="{{ $q }}">
                        <input type="hidden" name="country_id" value="{{ $countryId }}">
                        <input type="hidden" name="country_label" value="{{ $countryLabel }}">
                        <input type="hidden" name="non_operational" value="{{ $nonOperational }}">
                        <input type="hidden" name="mccmnc" value="{{ $mccmnc }}">
                        <input type="hidden" name="sort" value="{{ $sort }}">
                        <input type="hidden" name="direction" value="{{ $direction }}">
                        <span>Per page:</span>
                        <select
                            name="per_page"
                            onchange="this.form.submit()"
                            class="rounded-md border-gray-300 text-xs shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        >
                            @foreach ([10, 25, 50, 100, 200] as $opt)
                                <option value="{{ $opt }}" @selected($perPage === $opt)>{{ $opt }}</option>
                            @endforeach
                        </select>
                    </form>

                    <div>
                        {{ $networks->links() }}
                    </div>
                </div>
            </div>
        </div>
    </div>

    @push('scripts')
        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const countryInput   = document.getElementById('filter_country_name');
                const countryIdInput = document.getElementById('filter_country_id');
                const suggestions    = document.getElementById('country_suggestions');

                if (!countryInput || !countryIdInput || !suggestions) {
                    return;
                }

                let activeIndex = -1;
                const items = () => Array.from(suggestions.querySelectorAll('li'));

                const clearActive = () => {
                    items().forEach(li => li.classList.remove('bg-indigo-600', 'text-white'));
                };

                const openList = () => {
                    if (items().length) {
                        suggestions.classList.remove('hidden');
                    }
                };

                const closeList = () => {
                    suggestions.classList.add('hidden');
                    activeIndex = -1;
                    clearActive();
                };

                const setActiveIndex = (index) => {
                    const els = items();
                    if (!els.length) {
                        activeIndex = -1;
                        return;
                    }

                    if (index < 0) {
                        index = 0;
                    } else if (index >= els.length) {
                        index = els.length - 1;
                    }

                    activeIndex = index;

                    els.forEach((li, i) => {
                        if (i === activeIndex) {
                            li.classList.add('bg-indigo-600', 'text-white');
                            li.scrollIntoView({ block: 'nearest' });
                        } else {
                            li.classList.remove('bg-indigo-600', 'text-white');
                        }
                    });
                };

                const chooseActive = () => {
                    const els = items();
                    if (activeIndex < 0 || activeIndex >= els.length) return;

                    const li = els[activeIndex];
                    countryInput.value   = li.dataset.label || li.textContent.trim();
                    countryIdInput.value = li.dataset.id || '';
                    closeList();
                };

                countryInput.addEventListener('focus', () => {
                    openList();
                });

                countryInput.addEventListener('input', () => {
                    countryIdInput.value = '';
                    activeIndex = -1;
                    clearActive();
                    openList();
                });

                countryInput.addEventListener('keydown', (e) => {
                    const els = items();
                    if (!els.length) return;

                    if (e.key === 'ArrowDown') {
                        e.preventDefault();
                        if (suggestions.classList.contains('hidden')) {
                            openList();
                        }
                        setActiveIndex(activeIndex + 1);
                    } else if (e.key === 'ArrowUp') {
                        e.preventDefault();
                        if (activeIndex <= 0) {
                            setActiveIndex(els.length - 1);
                        } else {
                            setActiveIndex(activeIndex - 1);
                        }
                    } else if (e.key === 'Enter') {
                        if (!suggestions.classList.contains('hidden') && activeIndex >= 0) {
                            e.preventDefault();
                            chooseActive();
                        }
                    } else if (e.key === 'Escape') {
                        closeList();
                    }
                });

                items().forEach((li, index) => {
                    li.addEventListener('mousedown', (e) => {
                        e.preventDefault();
                        activeIndex = index;
                        chooseActive();
                    });
                });

                document.addEventListener('click', (e) => {
                    if (!suggestions.contains(e.target) && e.target !== countryInput) {
                        closeList();
                    }
                });
            });
        </script>
    @endpush
</x-app-layout>
