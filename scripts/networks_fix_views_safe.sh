#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BACKUP_DIR="backup_networks_views_$(date +%F_%H-%M-%S)"
echo "==> Backup dir: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

for f in resources/views/networks/edit.blade.php resources/views/networks/index.blade.php; do
  if [ -f "$f" ]; then
    echo "==> Backing up $f"
    cp "$f" "$BACKUP_DIR/$(basename "$f")"
  fi
done

echo "==> Writing safe edit.blade.php (no first() on null)"

cat > resources/views/networks/edit.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Edit Network: {{ $network->name }}
        </h2>
    </x-slot>

    @php
        // Safely determine default MCC from the first CountryMcc row (if any).
        $country  = $network->country ?? null;
        $firstMcc = null;

        if ($country) {
            // $country->mccs is an Eloquent relation (Collection)
            $firstMcc = $country->mccs->first();
        }

        $defaultMcc = $firstMcc && isset($firstMcc->mcc)
            ? str_pad((string) $firstMcc->mcc, 3, '0', STR_PAD_LEFT)
            : '';

        // Whether any MNC field failed validation (mncs.*.mnc)
        $hasMncError = $errors->has('mncs.*.mnc');
    @endphp

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
        @includeIf('partials.flash_log')

        {{-- Global error summary (Laravel validation) --}}
        @if ($errors->any())
            <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md text-sm">
                <div class="font-semibold mb-1">There were some problems with your input:</div>
                <ul class="list-disc list-inside space-y-0.5">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        {{-- Main edit form --}}
        <div class="bg-white shadow sm:rounded-lg p-6 space-y-6">
            <form method="POST" action="{{ route('networks.update', $network->id) }}">
                @csrf
                @method('PUT')

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    {{-- Country --}}
                    <div>
                        <label for="country_id" class="block text-sm font-medium text-gray-700">
                            Country
                        </label>
                        <select
                            id="country_id"
                            name="country_id"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            required
                        >
                            @foreach ($countries as $country)
                                <option value="{{ $country->id }}" @selected($country->id === $network->country_id)>
                                    {{ $country->name }} ({{ $country->iso2 }})
                                </option>
                            @endforeach
                        </select>
                        @error('country_id')
                            <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    {{-- Name --}}
                    <div>
                        <label for="name" class="block text-sm font-medium text-gray-700">
                            Name
                        </label>
                        <input
                            type="text"
                            id="name"
                            name="name"
                            value="{{ old('name', $network->name) }}"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            required
                        >
                        @error('name')
                            <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
                    {{-- Non-operational flag --}}
                    <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                            Status
                        </label>
                        <div class="flex items-center gap-2">
                            <input
                                type="checkbox"
                                id="non_operational"
                                name="non_operational"
                                value="1"
                                class="rounded border-gray-300 text-indigo-600 shadow-sm focus:ring-indigo-500"
                                @checked(optional($network->meta)->non_operational)
                            >
                            <label for="non_operational" class="text-sm text-gray-700">
                                Mark as non-operational
                            </label>
                        </div>
                    </div>

                    {{-- Notes --}}
                    <div>
                        <label for="notes" class="block text-sm font-medium text-gray-700">
                            Notes
                        </label>
                        <textarea
                            id="notes"
                            name="notes"
                            rows="4"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            placeholder="Internal notes about this network (e.g. outages, roaming only, special routing)..."
                        >{{ old('notes', optional($network->meta)->notes) }}</textarea>
                        @error('notes')
                            <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                {{-- MCC/MNC editable table --}}
                <div class="mt-8 space-y-3">
                    <div class="flex items-center justify-between">
                        <h3 class="text-lg font-semibold text-gray-900">
                            MCC / MNCs
                        </h3>
                        <button
                            type="button"
                            id="add-mnc-row"
                            class="inline-flex items-center rounded-md border border-gray-300 bg-white px-3 py-1.5 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50"
                        >
                            + Add MCC/MNC
                        </button>
                    </div>

                    @php
                        $oldMncs = old('mncs');
                        $rows = [];

                        if (is_array($oldMncs)) {
                            foreach ($oldMncs as $idx => $row) {
                                $rows[] = [
                                    'mcc' => $row['mcc'] ?? '',
                                    'mnc' => $row['mnc'] ?? '',
                                ];
                            }
                        } else {
                            foreach ($network->mncs as $mnc) {
                                $rows[] = [
                                    'mcc' => str_pad((string) $mnc->mcc, 3, '0', STR_PAD_LEFT),
                                    'mnc' => str_pad((string) $mnc->mnc, 2, '0', STR_PAD_LEFT),
                                ];
                            }
                        }
                    @endphp

                    <div class="overflow-x-auto">
                        <table id="mncs-table" class="min-w-full divide-y divide-gray-200 text-sm">
                            <thead class="bg-gray-50">
                                <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                                    <th class="px-4 py-2">MCC (from country)</th>
                                    <th class="px-4 py-2">MNC</th>
                                    <th class="px-4 py-2 w-24 text-right">Actions</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-gray-200">
                                @forelse ($rows as $idx => $row)
                                    <tr data-row="1">
                                        <td class="px-4 py-2">
                                            <input
                                                type="text"
                                                name="mncs[{{ $idx }}][mcc]"
                                                value="{{ $row['mcc'] !== '' ? $row['mcc'] : $defaultMcc }}"
                                                class="mt-1 block w-full rounded-md border-gray-200 bg-gray-100 text-gray-600 shadow-sm text-xs font-mono"
                                                readonly
                                            >
                                        </td>
                                        <td class="px-4 py-2">
                                            <input
                                                type="text"
                                                name="mncs[{{ $idx }}][mnc]"
                                                value="{{ $row['mnc'] }}"
                                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs font-mono @if($hasMncError) border-red-300 @endif"
                                                placeholder="MNC (2-3 digits)"
                                            >
                                            @if ($hasMncError)
                                                <p class="mt-1 text-xs text-red-600">
                                                    Each MNC must be 2 or 3 digits (0–9).
                                                </p>
                                            @endif
                                        </td>
                                        <td class="px-4 py-2 text-right">
                                            <button
                                                type="button"
                                                class="js-remove-mnc-row inline-flex items-center rounded-md border border-gray-300 bg-white px-2 py-1 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50"
                                            >
                                                Remove
                                            </button>
                                        </td>
                                    </tr>
                                @empty
                                    {{-- If empty, JS will add one row using defaultMcc --}}
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                    <p class="text-xs text-gray-500">
                        MCC is taken from the linked country and is read-only. Removing a row will delete that MCC/MNC from this network when you save.
                    </p>
                    @if ($hasMncError)
                        <p class="text-xs text-red-600 mt-1">
                            One or more MNC values are invalid. Each MNC must be 2 or 3 digits (0–9).
                        </p>
                    @endif
                </div>

                <div class="mt-6 flex items-center justify-end gap-3">
                    <a
                        href="{{ route('networks.index') }}"
                        class="inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50"
                    >
                        Back to list
                    </a>

                    <button
                        type="submit"
                        class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                    >
                        Save
                    </button>
                </div>
            </form>
        </div>
    </div>

    <script>
        (function () {
            var tableBody = document.querySelector('#mncs-table tbody');
            if (!tableBody) return;

            var addBtn = document.getElementById('add-mnc-row');
            var rows   = tableBody.querySelectorAll('tr[data-row]');
            var index  = rows.length;
            var defaultMcc = @json($defaultMcc);

            function addRow(mcc, mnc) {
                if (!mcc) mcc = defaultMcc || '';
                if (mnc === undefined) mnc = '';

                var tr = document.createElement('tr');
                tr.setAttribute('data-row', '1');

                tr.innerHTML =
                    '<td class="px-4 py-2">' +
                        '<input type="text" name="mncs[' + index + '][mcc]" value="' + (mcc || '') + '"' +
                        ' class="mt-1 block w-full rounded-md border-gray-200 bg-gray-100 text-gray-600 shadow-sm text-xs font-mono"' +
                        ' readonly>' +
                    '</td>' +
                    '<td class="px-4 py-2">' +
                        '<input type="text" name="mncs[' + index + '][mnc]" value="' + (mnc || '') + '"' +
                        ' class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs font-mono"' +
                        ' placeholder="MNC (2-3 digits)">' +
                    '</td>' +
                    '<td class="px-4 py-2 text-right">' +
                        '<button type="button" class="js-remove-mnc-row inline-flex items-center rounded-md border border-gray-300 bg-white px-2 py-1 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50">' +
                            'Remove' +
                        '</button>' +
                    '</td>';

                tableBody.appendChild(tr);
                index += 1;
            }

            if (!tableBody.querySelector('tr[data-row]')) {
                addRow(defaultMcc, '');
            }

            if (addBtn) {
                addBtn.addEventListener('click', function () {
                    addRow(defaultMcc, '');
                });
            }

            tableBody.addEventListener('click', function (e) {
                var btn = e.target.closest('.js-remove-mnc-row');
                if (!btn) return;

                var tr = btn.closest('tr');
                if (tr) {
                    tr.remove();
                }
            });
        })();
    </script>
</x-app-layout>
BLADE

echo "==> Writing index.blade.php with 'Create network' button in filters frame"

cat > resources/views/networks/index.blade.php << 'BLADE'
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
        $mccmnc         = trim((string) $request->input('mccmnc', ''));
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

        if ($mccmnc !== '') {
            $needle = $mccmnc;
            $query->whereExists(function ($sub) use ($needle) {
                $sub->from('network_mncs as nmn')
                    ->whereColumn('nmn.network_id', 'networks.id')
                    ->whereRaw(
                        "CAST(nmn.mcc AS text) || LPAD(CAST(nmn.mnc AS text), 2, '0') LIKE ?",
                        [$needle . '%']
                    );
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
            {{-- Filters in one *horizontal* row --}}
            <form method="GET" action="{{ route('networks.index') }}" id="networks-filter-form">
                <div
                    class="grid grid-cols-1 md:grid-cols-6 gap-4 items-end"
                    style="
                        display: flex;
                        flex-direction: row;
                        align-items: flex-end;
                        gap: 1rem;
                        flex-wrap: nowrap;
                        overflow-x: auto;
                    "
                >
                    {{-- Search by name (q) --}}
                    <div style="min-width: 200px;">
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
                    <div class="relative" style="min-width: 260px;">
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

                    {{-- MCCMNC filter (starts with) --}}
                    <div style="min-width: 140px;">
                        <label for="filter_mccmnc" class="block text-sm font-medium text-gray-700">
                            MCCMNC
                        </label>
                        <input
                            type="text"
                            id="filter_mccmnc"
                            name="mccmnc"
                            value="{{ $mccmnc }}"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            placeholder="e.g. 20201"
                        >
                    </div>

                    {{-- Non-operational filter (last filter) --}}
                    <div style="min-width: 160px;">
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

                    {{-- Actions: apply/reset/create --}}
                    <div style="min-width: 240px; display:flex; justify-content:flex-end; gap:0.5rem;">
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
                            href="{{ route('networks.create') }}"
                            class="inline-flex items-center px-3 py-2 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
                        >
                            + Create network
                        </a>
                    </div>
                </div>

                {{-- Preserve sort/direction/per_page across filter submissions --}}
                <input type="hidden" name="sort" id="networks_sort" value="{{ $sort }}">
                <input type="hidden" name="direction" id="networks_direction" value="{{ $direction }}">
                <input type="hidden" name="per_page" id="networks_per_page" value="{{ $perPage }}">
            </form>

            {{-- Results table --}}
            <div class="overflow-x-auto rounded-lg border bg-white mt-4">
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
                                MCCs
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
                                $mccs = $network->mncs
                                    ->pluck('mcc')
                                    ->map(function ($val) {
                                        return str_pad((string) $val, 3, '0', '0');
                                    })
                                    ->unique()
                                    ->values();

                                $mncs = $network->mncs
                                    ->pluck('mnc')
                                    ->map(function ($val) {
                                        return str_pad((string) $val, 2, '0', '0');
                                    })
                                    ->unique()
                                    ->values();
                            @endphp
                            <tr class="text-sm text-gray-700">
                                <td class="px-4 py-2 whitespace-nowrap">
                                    <div class="font-medium text-gray-900">
                                        {{ $network->country_name ?? optional($network->country)->name ?? '—' }}
                                    </div>
                                    <div class="text-xs text-gray-500">
                                        {{ $network->country_iso2 ?? optional($network->country)->iso2 ?? '' }}
                                    </div>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    <div class="font-medium text-gray-900">
                                        {{ $network->name }}
                                    </div>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    <div class="flex flex-wrap gap-1">
                                        @forelse ($mccs as $mcc)
                                            <span class="inline-flex items-center rounded-full bg-blue-100 px-2 py-0.5 text-xs font-semibold text-blue-800">
                                                {{ $mcc }}
                                            </span>
                                        @empty
                                            <span class="text-xs text-gray-400">—</span>
                                        @endforelse
                                    </div>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    <div class="flex flex-wrap gap-1">
                                        @forelse ($mncs as $mnc)
                                            <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs font-semibold text-gray-800">
                                                {{ $mnc }}
                                            </span>
                                        @empty
                                            <span class="text-xs text-gray-400">—</span>
                                        @endforelse
                                    </div>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    @if ($network->non_operational)
                                        <span class="inline-flex rounded-full bg-red-100 px-2 py-0.5 text-xs font-semibold text-red-700">
                                            Non-operational
                                        </span>
                                    @else
                                        <span class="inline-flex rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-700">
                                            Operational
                                        </span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap max-w-xs">
                                    @if ($network->meta_notes)
                                        <span class="text-xs text-gray-700 line-clamp-2">
                                            {{ $network->meta_notes }}
                                        </span>
                                    @else
                                        <span class="text-xs text-gray-400">—</span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-right">
                                    <div class="flex items-center justify-end gap-2">
                                        <a href="{{ route('networks.edit', $network) }}"
                                           class="inline-flex items-center rounded-md border border-gray-300 bg-white px-3 py-1 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50">
                                            Edit
                                        </a>
                                        <form method="POST" action="{{ route('networks.destroy', $network) }}"
                                              onsubmit="return confirm('Are you sure you want to delete this network?');">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit"
                                                    class="inline-flex items-center rounded-md border border-red-300 bg-white px-3 py-1 text-xs font-medium text-red-700 shadow-sm hover:bg-red-50">
                                                Delete
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" class="px-4 py-6 text-center text-sm text-gray-500">
                                    No networks found.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{-- Pagination + per-page selector at bottom --}}
            <div class="mt-4 flex flex-col md:flex-row md:items-center md:justify-between gap-3">
                <div class="text-sm text-gray-600">
                    @if ($networks->total() > 0)
                        Showing
                        <span class="font-semibold">{{ $networks->firstItem() }}</span>
                        to
                        <span class="font-semibold">{{ $networks->lastItem() }}</span>
                        of
                        <span class="font-semibold">{{ $networks->total() }}</span>
                        networks
                    @else
                        No networks to display.
                    @endif
                </div>
                <div>
                    {{ $networks->links() }}
                </div>
            </div>

            <div class="mt-2 flex items-center justify-end space-x-2">
                <label for="networks_per_page_select" class="text-xs text-gray-600">
                    Results per page:
                </label>
                <select
                    id="networks_per_page_select"
                    class="rounded-md border-gray-300 text-xs shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                >
                    @foreach ([10, 25, 50, 100, 200] as $opt)
                        <option value="{{ $opt }}" @selected($perPage === $opt)>{{ $opt }}</option>
                    @endforeach
                </select>
            </div>
        </div>
    </div>

    {{-- Country typeahead keyboard navigation + per-page handler --}}
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const input     = document.getElementById('filter_country_name');
            const hiddenId  = document.getElementById('filter_country_id');
            const list      = document.getElementById('country_suggestions');
            const form      = document.getElementById('networks-filter-form');
            const perSelect = document.getElementById('networks_per_page_select');
            const perHidden = document.getElementById('networks_per_page');

            if (perSelect && perHidden && form) {
                perSelect.addEventListener('change', function () {
                    perHidden.value = this.value;
                    form.submit();
                });
            }

            if (!input || !hiddenId || !list) {
                return;
            }

            let items = Array.from(list.querySelectorAll('li'));
            let activeIndex = -1;

            function resetHighlight() {
                items.forEach(li => li.classList.remove('bg-indigo-600', 'text-white'));
            }

            function highlightItem(li) {
                resetHighlight();
                if (li) {
                    li.classList.add('bg-indigo-600', 'text-white');
                }
            }

            function visibleItems() {
                return items.filter(li => !li.classList.contains('hidden'));
            }

            function openList() {
                list.classList.remove('hidden');
            }

            function closeList() {
                list.classList.add('hidden');
                activeIndex = -1;
                resetHighlight();
            }

            function selectItem(li) {
                if (!li) return;
                const id    = li.getAttribute('data-id') || '';
                const label = li.getAttribute('data-label') || '';

                hiddenId.value = id;
                input.value    = label;

                closeList();

                if (form) form.submit();
            }

            input.addEventListener('focus', function () {
                if (input.value.trim() !== '') {
                    openList();
                }
            });

            input.addEventListener('input', function () {
                const term = input.value.toLowerCase();

                items.forEach(li => {
                    const label = (li.getAttribute('data-label') || '').toLowerCase();
                    if (!term || label.includes(term)) {
                        li.classList.remove('hidden');
                    } else {
                        li.classList.add('hidden');
                    }
                });

                const vis = visibleItems();
                if (vis.length > 0) {
                    openList();
                } else {
                    closeList();
                }
                activeIndex = -1;
                resetHighlight();
            });

            input.addEventListener('keydown', function (e) {
                const vis = visibleItems();
                if (!vis.length) return;

                if (e.key === 'ArrowDown') {
                    e.preventDefault();
                    activeIndex = (activeIndex + 1) % vis.length;
                    highlightItem(vis[activeIndex]);
                } else if (e.key === 'ArrowUp') {
                    e.preventDefault();
                    activeIndex = (activeIndex - 1 + vis.length) % vis.length;
                    highlightItem(vis[activeIndex]);
                } else if (e.key === 'Enter') {
                    if (activeIndex >= 0 && activeIndex < vis.length) {
                        e.preventDefault();
                        selectItem(vis[activeIndex]);
                    }
                } else if (e.key === 'Escape') {
                    closeList();
                }
            });

            list.addEventListener('click', function (e) {
                const li = e.target.closest('li[data-id]');
                if (!li) return;
                selectItem(li);
            });

            document.addEventListener('click', function (e) {
                if (!list.contains(e.target) && e.target !== input) {
                    closeList();
                }
            });
        });
    </script>
</x-app-layout>
BLADE

echo "==> Clearing compiled views & caches inside app container"
docker compose exec app sh -lc '
  cd /var/www/html &&
  php artisan view:clear &&
  php artisan optimize:clear || true
'

echo "==> Done. Test /networks and /networks/{id}/edit in browser."
