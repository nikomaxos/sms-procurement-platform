<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offers
        </h2>
    </x-slot>

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        @if (session('status'))
            <div class="mb-4 text-sm text-green-600">
                {{ session('status') }}
            </div>
        @endif

        <div class="flex items-center justify-between mb-4">
            <h1 class="text-2xl font-semibold text-gray-800">
                Offers
            </h1>
            <a href="{{ route('offers.create') }}"
               class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                + New Offer
            </a>
        </div>

        {{-- Filters --}}
        <form method="GET" action="{{ route('offers.index') }}" class="mb-4 space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
                {{-- Country (typeahead-style label + hidden id) --}}
                <div>
                    <label for="country_label" class="block text-sm font-medium text-gray-700">
                        Country
                    </label>
                    <input
                        type="text"
                        id="country_label"
                        name="country_label"
                        value="{{ old('country_label', $filters['country_label'] ?? '') }}"
                        autocomplete="off"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                        placeholder="Type to search..."
                    />
                    <input type="hidden" name="country_id" id="country_id"
                           value="{{ old('country_id', $filters['country_id'] ?? '') }}">
                    <ul id="country_suggestions"
                        class="mt-1 max-h-40 overflow-auto border border-gray-200 rounded-md bg-white text-sm hidden z-10">
                        @foreach($countries as $country)
                            <li class="px-2 py-1 cursor-pointer hover:bg-blue-50"
                                data-id="{{ $country->id }}"
                                data-label="{{ $country->name }}">
                                {{ $country->name }}
                            </li>
                        @endforeach
                    </ul>
                </div>

                {{-- Network --}}
                <div>
                    <label for="network_id" class="block text-sm font-medium text-gray-700">
                        Network
                    </label>
                    <select id="network_id" name="network_id"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($networkOptions as $network)
                            <option value="{{ $network->id }}"
                                @selected(($filters['network_id'] ?? null) == $network->id)>
                                {{ $network->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- MNC --}}
                <div>
                    <label for="network_mnc_id" class="block text-sm font-medium text-gray-700">
                        MNC
                    </label>
                    <select id="network_mnc_id" name="network_mnc_id"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($networkMncOptions as $mnc)
                            <option value="{{ $mnc->id }}"
                                @selected(($filters['network_mnc_id'] ?? null) == $mnc->id)>
                                {{ $mnc->mnc }} ({{ $mnc->mcc_mnc }})
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- MCCMNC (text filter) --}}
                <div>
                    <label for="mccmnc" class="block text-sm font-medium text-gray-700">
                        MCCMNC
                    </label>
                    <input
                        type="text"
                        id="mccmnc"
                        name="mccmnc"
                        value="{{ old('mccmnc', $filters['mccmnc'] ?? '') }}"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                        placeholder="e.g. 20201"
                    />
                </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
                {{-- Supplier (typeahead) --}}
                <div>
                    <label for="supplier_label" class="block text-sm font-medium text-gray-700">
                        Supplier
                    </label>
                    <input
                        type="text"
                        id="supplier_label"
                        name="supplier_label"
                        value="{{ old('supplier_label', $filters['supplier_label'] ?? '') }}"
                        autocomplete="off"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                        placeholder="Type to search..."
                    />
                    <input type="hidden" name="supplier_id" id="supplier_id"
                           value="{{ old('supplier_id', $filters['supplier_id'] ?? '') }}">
                    <ul id="supplier_suggestions"
                        class="mt-1 max-h-40 overflow-auto border border-gray-200 rounded-md bg-white text-sm hidden z-10">
                        @foreach($suppliers as $supplier)
                            <li class="px-2 py-1 cursor-pointer hover:bg-blue-50"
                                data-id="{{ $supplier->id }}"
                                data-label="{{ $supplier->name }}">
                                {{ $supplier->name }}
                            </li>
                        @endforeach
                    </ul>
                </div>

                {{-- Connection --}}
                <div>
                    <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">
                        Connection
                    </label>
                    <select id="supplier_connection_id" name="supplier_connection_id"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($connectionOptions as $conn)
                            <option value="{{ $conn->id }}"
                                @selected(($filters['supplier_connection_id'] ?? null) == $conn->id)>
                                {{ $conn->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Product Type --}}
                <div>
                    <label for="product_type" class="block text-sm font-medium text-gray-700">
                        Product Type
                    </label>
                    <select id="product_type" name="product_type"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($productTypeOptions as $value => $label)
                            <option value="{{ $value }}"
                                @selected(($filters['product_type'] ?? null) === $value)>
                                {{ $label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Known Hops --}}
                <div>
                    <label for="known_hops" class="block text-sm font-medium text-gray-700">
                        Known Hops
                    </label>
                    <select id="known_hops" name="known_hops"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($knownHopsOptions as $value => $label)
                            <option value="{{ $value }}"
                                @selected(($filters['known_hops'] ?? null) === $value)>
                                {{ $label }}
                            </option>
                        @endforeach
                    </select>
                </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
                {{-- Sender Id Supported --}}
                <div>
                    <label for="sender_id_supported" class="block text-sm font-medium text-gray-700">
                        Sender Id Supported
                    </label>
                    <select id="sender_id_supported" name="sender_id_supported"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($senderIdOptions as $value => $label)
                            <option value="{{ $value }}"
                                @selected(($filters['sender_id_supported'] ?? null) === $value)>
                                {{ $label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Charge Type --}}
                <div>
                    <label for="charge_type" class="block text-sm font-medium text-gray-700">
                        Charge Type
                    </label>
                    <select id="charge_type" name="charge_type"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        <option value="per_submit" @selected(($filters['charge_type'] ?? null) === 'per_submit')>
                            Per Submit
                        </option>
                        <option value="per_delivered" @selected(($filters['charge_type'] ?? null) === 'per_delivered')>
                            Per Delivered
                        </option>
                    </select>
                </div>

                {{-- Is Exclusive --}}
                <div>
                    <label for="is_exclusive" class="block text-sm font-medium text-gray-700">
                        Is Exclusive
                    </label>
                    <select id="is_exclusive" name="is_exclusive"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        <option value="1" @selected(($filters['is_exclusive'] ?? null) === '1')>Yes</option>
                        <option value="0" @selected(($filters['is_exclusive'] ?? null) === '0')>No</option>
                    </select>
                </div>

                {{-- Results per page --}}
                <div>
                    <label for="per_page" class="block text-sm font-medium text-gray-700">
                        Results per page
                    </label>
                    <select id="per_page" name="per_page"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        @foreach([25,50,100,200] as $option)
                            <option value="{{ $option }}" @selected($perPage == $option)>
                                {{ $option }}
                            </option>
                        @endforeach
                    </select>
                </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
                {{-- Price range --}}
                <div>
                    <label class="block text-sm font-medium text-gray-700">
                        Price min / max
                    </label>
                    <div class="mt-1 flex space-x-2">
                        <input type="text" name="price_min" id="price_min"
                               value="{{ old('price_min', $filters['price_min'] ?? '') }}"
                               class="block w-1/2 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                               placeholder="Min">
                        <input type="text" name="price_max" id="price_max"
                               value="{{ old('price_max', $filters['price_max'] ?? '') }}"
                               class="block w-1/2 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                               placeholder="Max">
                    </div>
                </div>

                {{-- Effective date range --}}
                <div>
                    <label class="block text-sm font-medium text-gray-700">
                        Effective date from / to
                    </label>
                    <div class="mt-1 flex space-x-2">
                        <input type="date" name="effective_from" id="effective_from"
                               value="{{ old('effective_from', $filters['effective_from'] ?? '') }}"
                               class="block w-1/2 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <input type="date" name="effective_to" id="effective_to"
                               value="{{ old('effective_to', $filters['effective_to'] ?? '') }}"
                               class="block w-1/2 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                    </div>
                </div>
            </div>

            <div class="mt-3 flex space-x-2 justify-end">
                <button type="submit"
                        class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                    Apply filters
                </button>
                <a href="{{ route('offers.index') }}"
                   class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                    Reset
                </a>
            </div>
        </form>

        {{-- Bulk update + table --}}
        <form method="POST" action="{{ route('offers.bulk-update') }}">
            @csrf

            <div class="bg-white shadow-sm rounded-lg overflow-hidden">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                    <thead class="bg-gray-50">
                        <tr>
                            <th class="px-3 py-2">
                                <input type="checkbox" id="select_all_offers"
                                       class="h-4 w-4 text-blue-600 border-gray-300 rounded">
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Country
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Network
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                MCCMNC
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Supplier
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Connection
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Username
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Product Type
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Known Hops
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Sender Id Supported
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Price
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Charge Type
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Is Exclusive
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Effective Date
                            </th>
                            <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Actions
                            </th>
                        </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                        @forelse($offers as $offer)
                            @php
                                $prev = $offer->latestHistory;
                            @endphp
                            <tr>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    <input type="checkbox"
                                           name="offer_ids[]"
                                           value="{{ $offer->id }}"
                                           class="offer_checkbox h-4 w-4 text-blue-600 border-gray-300 rounded">
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->country?->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->network?->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->mcc_mnc }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->supplier?->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->connection?->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->connection?->username }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->product_type }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->known_hops }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->sender_id_supported }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    <a href="{{ route('offers.history', $offer) }}"
                                       target="_blank"
                                       class="text-indigo-600 hover:text-indigo-900"
                                       @if($prev)
                                           title="Previous: {{ $prev->price }} ({{ $prev->effective_date?->format('Y-m-d') }})"
                                       @endif
                                    >
                                        {{ number_format((float) $offer->price, 6) }}
                                    </a>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    @if($offer->charge_type === 'per_submit')
                                        Per Submit
                                    @elseif($offer->charge_type === 'per_delivered')
                                        Per Delivered
                                    @else
                                        {{ $offer->charge_type }}
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    @if($offer->is_exclusive)
                                        <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-green-50 text-green-700 text-xs">
                                            Yes
                                        </span>
                                    @else
                                        <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-gray-50 text-gray-500 text-xs">
                                            No
                                        </span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    <a href="{{ route('offers.history', $offer) }}"
                                       target="_blank"
                                       class="text-indigo-600 hover:text-indigo-900"
                                       @if($prev)
                                           title="Previous: {{ $prev->price }} ({{ $prev->effective_date?->format('Y-m-d') }})"
                                       @endif
                                    >
                                        {{ $offer->effective_date?->format('Y-m-d') }}
                                    </a>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-right text-sm">
                                    <a href="{{ route('offers.edit', $offer) }}"
                                       class="text-blue-600 hover:text-blue-900">
                                        Edit
                                    </a>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="15" class="px-4 py-4 text-center text-sm text-gray-500">
                                    No offers found.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div class="mt-4">
                {{ $offers->links() }}
            </div>

            {{-- Bulk update panel --}}
            <div class="mt-6 bg-white shadow-sm rounded-lg p-4">
                <h3 class="text-sm font-semibold text-gray-800 mb-3">
                    Bulk update selected offers
                </h3>
                <div class="grid grid-cols-1 md:grid-cols-5 gap-3">
                    <div>
                        <label for="bulk_route_type" class="block text-xs font-medium text-gray-700">
                            Route Type
                        </label>
                        <input type="text" id="bulk_route_type" name="bulk_route_type"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-xs"
                               placeholder="Leave blank = no change">
                    </div>

                    <div>
                        <label for="bulk_known_hops" class="block text-xs font-medium text-gray-700">
                            Known Hops
                        </label>
                        <select id="bulk_known_hops" name="bulk_known_hops"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-xs">
                            <option value="">(no change)</option>
                            @foreach($knownHopsOptions as $value => $label)
                                <option value="{{ $value }}">{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label for="bulk_sender_id_supported" class="block text-xs font-medium text-gray-700">
                            Sender Id Supported
                        </label>
                        <select id="bulk_sender_id_supported" name="bulk_sender_id_supported"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-xs">
                            <option value="">(no change)</option>
                            @foreach($senderIdOptions as $value => $label)
                                <option value="{{ $value }}">{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label for="bulk_charge_type" class="block text-xs font-medium text-gray-700">
                            Charge Model
                        </label>
                        <select id="bulk_charge_type" name="bulk_charge_type"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-xs">
                            <option value="">(no change)</option>
                            <option value="per_submit">Per Submit</option>
                            <option value="per_delivered">Per Delivered</option>
                        </select>
                    </div>

                    <div>
                        <label for="bulk_is_exclusive" class="block text-xs font-medium text-gray-700">
                            Is Exclusive
                        </label>
                        <select id="bulk_is_exclusive" name="bulk_is_exclusive"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-xs">
                            <option value="">(no change)</option>
                            <option value="1">Set: Yes</option>
                            <option value="0">Set: No</option>
                        </select>
                    </div>
                </div>

                <div class="mt-3 flex justify-end">
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-indigo-600 text-white hover:bg-indigo-700">
                        Apply to selected
                    </button>
                </div>
            </div>
        </form>
    </div>

    {{-- Simple JS for country/supplier suggestions + select-all --}}
    <script>
        (function () {
            function setupTypeahead(inputId, hiddenId, listId) {
                const input = document.getElementById(inputId);
                const hidden = document.getElementById(hiddenId);
                const list = document.getElementById(listId);
                if (!input || !hidden || !list) return;

                let items = Array.from(list.querySelectorAll('li'));
                let currentIndex = -1;

                function closeList() {
                    list.classList.add('hidden');
                    currentIndex = -1;
                    items.forEach(li => li.classList.remove('bg-blue-100'));
                }

                function openList() {
                    list.classList.remove('hidden');
                }

                function highlight(index) {
                    items.forEach((li, i) => {
                        li.classList.toggle('bg-blue-100', i === index);
                    });
                }

                input.addEventListener('input', function () {
                    const val = this.value.toLowerCase();
                    items.forEach(li => {
                        const label = (li.dataset.label || '').toLowerCase();
                        li.style.display = label.includes(val) ? '' : 'none';
                    });
                    openList();
                });

                input.addEventListener('keydown', function (e) {
                    if (e.key === 'ArrowDown') {
                        e.preventDefault();
                        openList();
                        const visible = items.filter(li => li.style.display !== 'none');
                        if (!visible.length) return;
                        if (currentIndex < visible.length - 1) {
                            currentIndex++;
                        }
                        highlightIndexInVisible(visible);
                    } else if (e.key === 'ArrowUp') {
                        e.preventDefault();
                        const visible = items.filter(li => li.style.display !== 'none');
                        if (!visible.length) return;
                        if (currentIndex > 0) {
                            currentIndex--;
                        }
                        highlightIndexInVisible(visible);
                    } else if (e.key === 'Enter') {
                        const visible = items.filter(li => li.style.display !== 'none');
                        if (currentIndex >= 0 && currentIndex < visible.length) {
                            e.preventDefault();
                            selectItem(visible[currentIndex]);
                        }
                    } else if (e.key === 'Escape') {
                        closeList();
                    }
                });

                function highlightIndexInVisible(visible) {
                    items.forEach(li => li.classList.remove('bg-blue-100'));
                    if (currentIndex >= 0 && currentIndex < visible.length) {
                        const li = visible[currentIndex];
                        li.classList.add('bg-blue-100');
                    }
                }

                function selectItem(li) {
                    input.value = li.dataset.label || '';
                    hidden.value = li.dataset.id || '';
                    closeList();
                }

                items.forEach(li => {
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
            }

            setupTypeahead('country_label', 'country_id', 'country_suggestions');
            setupTypeahead('supplier_label', 'supplier_id', 'supplier_suggestions');

            const selectAll = document.getElementById('select_all_offers');
            if (selectAll) {
                selectAll.addEventListener('change', function () {
                    document.querySelectorAll('.offer_checkbox').forEach(cb => {
                        cb.checked = selectAll.checked;
                    });
                });
            }
        })();
    </script>
</x-app-layout>
