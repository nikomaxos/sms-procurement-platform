<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ __('Offers') }}
        </h2>
    </x-slot>

    @php
        // Guard all the collections so we never get "undefined variable" in the view
        $countries               = $countries               ?? collect();
        $suppliers               = $suppliers               ?? collect();
        $networks                = $networks                ?? collect();
        $connections             = $connections             ?? collect();
        $productTypeItems        = $productTypeItems        ?? collect();
        $knownHopsItems          = $knownHopsItems          ?? collect();
        $senderIdSupportedItems  = $senderIdSupportedItems  ?? collect();

        // Convenience maps for lookup by id
        $countriesById      = $countries->keyBy('id');
        $suppliersById      = $suppliers->keyBy('id');
        $networksById       = $networks->keyBy('id');
        $connectionsById    = $connections->keyBy('id');
        $productTypeById    = $productTypeItems->keyBy('id');
        $knownHopsById      = $knownHopsItems->keyBy('id');
        $senderIdById       = $senderIdSupportedItems->keyBy('id');

        $filters = request()->all();

        $chargeTypes = [
            'per_submit'    => 'Per Submit',
            'per_delivered' => 'Per Delivered',
        ];
    @endphp

    <div class="py-6">
        <!-- Use ~90% window width -->
        <div class="w-11/12 mx-auto">
            <!-- Header row with create button -->
            <div class="flex items-center justify-between mb-4">
                <h2 class="text-lg font-semibold text-gray-800">
                    {{ __('Offers') }}
                </h2>
                <a href="{{ route('offers.create') }}"
                   class="inline-flex items-center px-4 py-2 rounded-md bg-indigo-600 text-white text-sm font-medium hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                    + {{ __('New Offer') }}
                </a>
            </div>

            <!-- Filters card -->
            <div class="bg-white shadow rounded-lg mb-4">
                <div class="px-4 py-3 sm:px-6 border-b">
                    <h3 class="text-sm font-semibold text-gray-700">
                        {{ __('Filters') }}
                    </h3>
                </div>

                <div class="px-4 py-4 sm:px-6">
                    <form method="GET"
                          action="{{ route('offers.index') }}"
                          id="offers-filters-form"
                          class="space-y-4">

                        <!-- Filters in responsive grid: 5 per row on md+ -->
                        <div class="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-5 lg:grid-cols-5 xl:grid-cols-5 gap-3" style="grid-template-columns: repeat(5, minmax(0, 1fr));">
                            <!-- Country -->
                            <div>
                                <label for="filter-country" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Country') }}
                                </label>
                                <select name="country_id"
                                        id="filter-country"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('All') }}</option>
                                    @foreach ($countries as $country)
                                        <option value="{{ $country->id }}"
                                            @selected(($filters['country_id'] ?? '') == $country->id)>
                                            {{ $country->name }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            <!-- Network -->
                            <div>
                                <label for="filter-network" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Network') }}
                                </label>
                                <select name="network_id"
                                        id="filter-network"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('All') }}</option>
                                    @foreach ($networks as $network)
                                        <option value="{{ $network->id }}"
                                                data-country-id="{{ $network->country_id ?? '' }}"
                                            @selected(($filters['network_id'] ?? '') == $network->id)>
                                            {{ $network->name }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            <!-- Supplier -->
                            <div>
                                <label for="filter-supplier" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Supplier') }}
                                </label>
                                <select name="supplier_id"
                                        id="filter-supplier"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('All') }}</option>
                                    @foreach ($suppliers as $supplier)
                                        <option value="{{ $supplier->id }}"
                                            @selected(($filters['supplier_id'] ?? '') == $supplier->id)>
                                            {{ $supplier->name }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            <!-- Connection -->
                            <div>
                                <label for="filter-connection" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Connection') }}
                                </label>
                                <select name="supplier_connection_id"
                                        id="filter-connection"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('All') }}</option>
                                    @foreach ($connections as $connection)
                                        <option value="{{ $connection->id }}"
                                                data-supplier-id="{{ $connection->supplier_id ?? '' }}"
                                            @selected(($filters['supplier_connection_id'] ?? '') == $connection->id)>
                                            {{ $connection->name }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            <!-- Product Type -->
                            <div>
                                <label for="filter-product-type" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Product Type') }}
                                </label>
                                <select name="product_type_id"
                                        id="filter-product-type"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('All') }}</option>
                                    @foreach ($productTypeItems as $item)
                                        <option value="{{ $item->id }}"
                                            @selected(($filters['product_type_id'] ?? '') == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            <!-- Known Hops -->
                            <div>
                                <label for="filter-known-hops" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Known Hops') }}
                                </label>
                                <select name="known_hops_dropdown_item_id"
                                        id="filter-known-hops"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('All') }}</option>
                                    @foreach ($knownHopsItems as $item)
                                        <option value="{{ $item->id }}"
                                            @selected(($filters['known_hops_dropdown_item_id'] ?? '') == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            <!-- Sender ID Supported -->
                            <div>
                                <label for="filter-sender-id" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Sender ID Supported') }}
                                </label>
                                <select name="sender_id_supported_dropdown_item_id"
                                        id="filter-sender-id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('All') }}</option>
                                    @foreach ($senderIdSupportedItems as $item)
                                        <option value="{{ $item->id }}"
                                            @selected(($filters['sender_id_supported_dropdown_item_id'] ?? '') == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            <!-- Charge Type -->
                            <div>
                                <label for="filter-charge-type" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Charge Type') }}
                                </label>
                                <select name="charge_type"
                                        id="filter-charge-type"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('All') }}</option>
                                    @foreach ($chargeTypes as $value => $label)
                                        <option value="{{ $value }}"
                                            @selected(($filters['charge_type'] ?? '') === $value)>
                                            {{ $label }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            <!-- Max price -->
                            <div>
                                <label for="filter-max-price" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Max Price (≤ 1.0)') }}
                                </label>
                                <input type="number"
                                       step="0.000001"
                                       min="0"
                                       max="1"
                                       name="max_price"
                                       id="filter-max-price"
                                       value="{{ $filters['max_price'] ?? '' }}"
                                       class="w-full rounded-md border-gray-300 text-xs sm:text-sm" />
                            </div>
                        </div>

                        <div class="mt-3 flex items-center gap-3">
                            <button type="submit"
                                    class="inline-flex items-center px-4 py-2 rounded-md bg-indigo-600 text-white text-sm font-medium hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                                {{ __('Apply Filters') }}
                            </button>
                            <a href="{{ route('offers.index') }}"
                               class="text-sm text-gray-500 hover:text-gray-700">
                                {{ __('Reset') }}
                            </a>
                        </div>
                    </form>
                </div>
            </div>

            <!-- Offers table + bulk update -->
            <div class="bg-white shadow rounded-lg">
                <div class="px-4 py-3 sm:px-6 border-b flex items-center justify-between">
                    <div class="text-sm text-gray-600">
                        @if (isset($offers) && method_exists($offers, 'total'))
                            {{ __('Showing :from–:to of :total offers', [
                                'from' => $offers->firstItem() ?? 0,
                                'to'   => $offers->lastItem() ?? 0,
                                'total'=> $offers->total() ?? 0,
                            ]) }}
                        @else
                            {{ __('Offers') }}
                        @endif
                    </div>
                    <button id="mass-update-toggle"
                            type="button"
                            class="inline-flex items-center px-3 py-1.5 rounded-md bg-gray-800 text-white text-xs font-medium hover:bg-gray-900 disabled:opacity-40 disabled:cursor-not-allowed"
                            disabled>
                        {{ __('Mass Update Selected') }}
                    </button>
                </div>

                <form method="POST" action="{{ route('offers.bulk_update') }}" id="bulk-update-form">
                    @csrf
                    <input type="hidden" name="offer_ids" id="bulk-offer-ids">

                    <!-- Bulk update panel (hidden until Mass Update clicked) -->
                    <div id="bulk-update-panel"
                         class="px-4 py-4 sm:px-6 bg-gray-50 border-b hidden">
                        <div class="text-sm font-semibold text-gray-700 mb-3">
                            {{ __('Bulk update fields (leave empty to keep unchanged)') }}
                        </div>

                        <div class="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-4 gap-3">
                            <div>
                                <label class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Product Type') }}
                                </label>
                                <select name="product_type_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('— Leave unchanged —') }}</option>
                                    @foreach ($productTypeItems as $item)
                                        <option value="{{ $item->id }}">{{ $item->label }}</option>
                                    @endforeach
                                </select>
                            </div>

                            <div>
                                <label class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Known Hops') }}
                                </label>
                                <select name="known_hops_dropdown_item_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('— Leave unchanged —') }}</option>
                                    @foreach ($knownHopsItems as $item)
                                        <option value="{{ $item->id }}">{{ $item->label }}</option>
                                    @endforeach
                                </select>
                            </div>

                            <div>
                                <label class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Sender ID Supported') }}
                                </label>
                                <select name="sender_id_supported_dropdown_item_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('— Leave unchanged —') }}</option>
                                    @foreach ($senderIdSupportedItems as $item)
                                        <option value="{{ $item->id }}">{{ $item->label }}</option>
                                    @endforeach
                                </select>
                            </div>

                            <div>
                                <label class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Charge Type') }}
                                </label>
                                <select name="charge_type"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('— Leave unchanged —') }}</option>
                                    @foreach ($chargeTypes as $value => $label)
                                        <option value="{{ $value }}">{{ $label }}</option>
                                    @endforeach
                                </select>
                            </div>
                        </div>

                        <div class="mt-4 flex items-center gap-3">
                            <button type="submit"
                                    class="inline-flex items-center px-4 py-2 rounded-md bg-indigo-600 text-white text-sm font-medium hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                                {{ __('Apply Bulk Update') }}
                            </button>
                            <button type="button"
                                    id="mass-update-cancel"
                                    class="text-sm text-gray-500 hover:text-gray-700">
                                {{ __('Cancel') }}
                            </button>
                        </div>
                    </div>

                    <div class="overflow-x-auto">
                        <table class="min-w-full divide-y divide-gray-200 text-xs sm:text-sm">
                            <thead class="bg-gray-50">
                                <tr>
                                    <th class="px-3 py-2 text-left text-[10px] font-medium text-gray-500 uppercase tracking-wider">
                                        <input type="checkbox"
                                               id="select-all-offers"
                                               class="rounded border-gray-300">
                                    </th>
                                    <th class="px-3 py-2 text-left text-[10px] font-medium text-gray-500 uppercase tracking-wider">
                                        {{ __('Country') }}
                                    </th>
                                    <th class="px-3 py-2 text-left text-[10px] font-medium text-gray-500 uppercase tracking-wider">
                                        {{ __('Network') }}
                                    </th>
                                    <th class="px-3 py-2 text-left text-[10px] font-medium text-gray-500 uppercase tracking-wider">
                                        {{ __('Supplier') }}
                                    </th>
                                    <th class="px-3 py-2 text-left text-[10px] font-medium text-gray-500 uppercase tracking-wider">
                                        {{ __('Connection') }}
                                    </th>
                                    <th class="px-3 py-2 text-right text-[10px] font-medium text-gray-500 uppercase tracking-wider">
                                        {{ __('Price') }}
                                    </th>
                                    <th class="px-3 py-2 text-left text-[10px] font-medium text-gray-500 uppercase tracking-wider">
                                        {{ __('MCCMNC') }}
                                    </th>
                                    <th class="px-3 py-2 text-left text-[10px] font-medium text-gray-500 uppercase tracking-wider">
                                        {{ __('Product Type') }}
                                    </th>
                                    <th class="px-3 py-2 text-left text-[10px] font-medium text-gray-500 uppercase tracking-wider">
                                        {{ __('Known Hops') }}
                                    </th>
                                    <th class="px-3 py-2 text-left text-[10px] font-medium text-gray-500 uppercase tracking-wider">
                                        {{ __('Sender ID Supported') }}
                                    </th>
                                    <th class="px-3 py-2 text-left text-[10px] font-medium text-gray-500 uppercase tracking-wider">
                                        {{ __('Charge Type') }}
                                    </th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-gray-100">
                                @forelse ($offers as $offer)
                                    @php
                                        $country    = $countriesById->get($offer->country_id ?? null);
                                        $network    = $networksById->get($offer->network_id ?? null);
                                        $supplier   = $suppliersById->get($offer->supplier_id ?? null);
                                        $connection = $connectionsById->get($offer->supplier_connection_id ?? null);
                                        $pt         = $productTypeById->get($offer->product_type_id ?? null);
                                        $kh         = $knownHopsById->get($offer->known_hops_dropdown_item_id ?? null);
                                        $sid        = $senderIdById->get($offer->sender_id_supported_dropdown_item_id ?? null);
                                    @endphp
                                    <tr>
                                        <td class="px-3 py-2 whitespace-nowrap">
                                            <input type="checkbox"
                                                   class="offer-checkbox rounded border-gray-300"
                                                   value="{{ $offer->id }}">
                                        </td>
                                        <td class="px-3 py-2 whitespace-nowrap text-[11px] text-gray-800">
                                            {{ $country->name ?? $offer->mcc ?? '-' }}
                                        </td>
                                        <td class="px-3 py-2 whitespace-nowrap text-[11px] text-gray-800">
                                            {{ $network->name ?? $offer->mnc ?? '-' }}
                                        </td>
                                        <td class="px-3 py-2 whitespace-nowrap text-[11px] text-gray-800">
                                            {{ $supplier->name ?? '-' }}
                                        </td>
                                        <td class="px-3 py-2 whitespace-nowrap text-[11px] text-gray-800">
                                            {{ $connection->name ?? '-' }}
                                        </td>
                                        <td class="px-3 py-2 whitespace-nowrap text-[11px] text-right text-gray-800">
                                            {{ number_format((float) $offer->price, 6) }}
                                        </td>
                                        <td class="px-3 py-2 whitespace-nowrap text-[11px] text-gray-800">
                                            {{ $offer->mcc_mnc ?? (($offer->mcc ?? '') . ($offer->mnc ?? '')) }}
                                        </td>
                                        <td class="px-3 py-2 whitespace-nowrap text-[11px] text-gray-800">
                                            {{ $pt->label ?? '-' }}
                                        </td>
                                        <td class="px-3 py-2 whitespace-nowrap text-[11px] text-gray-800">
                                            {{ $kh->label ?? '-' }}
                                        </td>
                                        <td class="px-3 py-2 whitespace-nowrap text-[11px] text-gray-800">
                                            {{ $sid->label ?? '-' }}
                                        </td>
                                        <td class="px-3 py-2 whitespace-nowrap text-[11px] text-gray-800">
                                            @if (!empty($offer->charge_type))
                                                {{ $chargeTypes[$offer->charge_type] ?? $offer->charge_type }}
                                            @else
                                                -
                                            @endif
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="11"
                                            class="px-3 py-4 text-center text-sm text-gray-500">
                                            {{ __('No offers found.') }}
                                        </td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>

                    <div class="px-4 py-3 sm:px-6 border-t">
                        @if (isset($offers) && method_exists($offers, 'links'))
                            {{ $offers->links() }}
                        @endif
                    </div>
                </form>
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const countryFilter    = document.getElementById('filter-country');
            const networkFilter    = document.getElementById('filter-network');
            const supplierFilter   = document.getElementById('filter-supplier');
            const connectionFilter = document.getElementById('filter-connection');

            // Preserve all original options to re-filter
            let allNetworkOptions = [];
            let allConnectionOptions = [];

            if (networkFilter) {
                allNetworkOptions = Array.from(networkFilter.options);
            }
            if (connectionFilter) {
                allConnectionOptions = Array.from(connectionFilter.options);
            }

            function applyNetworkCountryFilter() {
                if (!countryFilter || !networkFilter || allNetworkOptions.length === 0) return;
                const selectedCountry = countryFilter.value || '';

                const current = networkFilter.value;
                networkFilter.innerHTML = '';
                const placeholder = document.createElement('option');
                placeholder.value = '';
                placeholder.textContent = '{{ __('All') }}';
                networkFilter.appendChild(placeholder);

                allNetworkOptions.forEach(function (opt) {
                    const cid = opt.getAttribute('data-country-id') || '';
                    if (opt.value === '' || selectedCountry === '' || cid === selectedCountry) {
                        networkFilter.appendChild(opt);
                    }
                });

                if (current && Array.from(networkFilter.options).some(o => o.value === current)) {
                    networkFilter.value = current;
                }
            }

            function applyConnectionSupplierFilter() {
                if (!supplierFilter || !connectionFilter || allConnectionOptions.length === 0) return;
                const selectedSupplier = supplierFilter.value || '';

                const current = connectionFilter.value;
                connectionFilter.innerHTML = '';
                const placeholder = document.createElement('option');
                placeholder.value = '';
                placeholder.textContent = '{{ __('All') }}';
                connectionFilter.appendChild(placeholder);

                allConnectionOptions.forEach(function (opt) {
                    const sid = opt.getAttribute('data-supplier-id') || '';
                    if (opt.value === '' || selectedSupplier === '' || sid === selectedSupplier) {
                        connectionFilter.appendChild(opt);
                    }
                });

                if (current && Array.from(connectionFilter.options).some(o => o.value === current)) {
                    connectionFilter.value = current;
                }
            }

            if (countryFilter && networkFilter) {
                applyNetworkCountryFilter();
                countryFilter.addEventListener('change', applyNetworkCountryFilter);
            }

            if (supplierFilter && connectionFilter) {
                applyConnectionSupplierFilter();
                supplierFilter.addEventListener('change', applyConnectionSupplierFilter);
            }

            // Bulk selection + Mass update panel
            const selectAll   = document.getElementById('select-all-offers');
            const checkboxes  = Array.from(document.querySelectorAll('.offer-checkbox'));
            const massToggle  = document.getElementById('mass-update-toggle');
            const bulkPanel   = document.getElementById('bulk-update-panel');
            const bulkIds     = document.getElementById('bulk-offer-ids');
            const massCancel  = document.getElementById('mass-update-cancel');

            function updateMassState() {
                const anyChecked = checkboxes.some(cb => cb.checked);
                if (massToggle) {
                    massToggle.disabled = !anyChecked;
                }
            }

            if (selectAll) {
                selectAll.addEventListener('change', function () {
                    checkboxes.forEach(cb => cb.checked = selectAll.checked);
                    updateMassState();
                });
            }

            checkboxes.forEach(cb => {
                cb.addEventListener('change', updateMassState);
            });

            if (massToggle && bulkPanel && bulkIds) {
                massToggle.addEventListener('click', function () {
                    const ids = checkboxes
                        .filter(cb => cb.checked)
                        .map(cb => cb.value);
                    if (!ids.length) return;
                    bulkIds.value = ids.join(',');
                    bulkPanel.classList.remove('hidden');
                });
            }

            if (massCancel && bulkPanel) {
                massCancel.addEventListener('click', function () {
                    bulkPanel.classList.add('hidden');
                });
            }
        });
    </script>
</x-app-layout>
