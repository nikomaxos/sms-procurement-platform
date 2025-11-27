<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Edit Network: {{ $network->name }}
        </h2>
    </x-slot>

    @php
        // Default MCC from the first CountryMcc row (if any) — safe even if country is null.
        $defaultMcc = '';
        if ($network->country && $network->country->mccs && $network->country->mccs->count()) {
            $firstMcc = $network->country->mccs->first();
            if ($firstMcc && $firstMcc->mcc !== null) {
                $defaultMcc = str_pad((string) $firstMcc->mcc, 3, '0', STR_PAD_LEFT);
            }
        }

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

                <div class="mt-6 flex items-center justify-between gap-3">
                    <a
                        href="{{ route('networks.index') }}"
                        class="inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50"
                    >
                        Back to list
                    </a>

                    <div class="flex items-center gap-3">
                        <button
                            type="button"
                            onclick="if (confirm('Are you sure you want to delete this network?')) { document.getElementById('delete-network-form-{{ $network->id }}').submit(); }"
                            class="inline-flex items-center rounded-md border border-red-300 bg-white px-4 py-2 text-sm font-medium text-red-700 shadow-sm hover:bg-red-50"
                        >
                            Delete
                        </button>

                        <button
                            type="submit"
                            class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                        >
                            Save
                        </button>
                    </div>
                </div>
            </form>

            <form
                id="delete-network-form-{{ $network->id }}"
                method="POST"
                action="{{ route('networks.destroy', $network) }}"
                class="hidden"
            >
                @csrf
                @method('DELETE')
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
