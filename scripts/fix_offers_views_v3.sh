#!/usr/bin/env bash
set -euo pipefail

echo "Running fix_offers_views_v3.sh..."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F-%H%M%S)"
BACKUP_DIR=".backups/fix_offers_views_v3_${STAMP}"
echo "Backup dir: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  - Backing up $f"
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    cp "$f" "$BACKUP_DIR/$f"
  else
    echo "  - NOTE: $f did not exist, will create new"
  fi
}

INDEX="resources/views/offers/index.blade.php"
CREATE="resources/views/offers/create.blade.php"

backup_file "$INDEX"
backup_file "$CREATE"

###############################################################################
# 1) Rewrite OFFERS INDEX (5 filters per row, 90% width, Mass Update intact)
###############################################################################
cat > "$INDEX" << 'BLADE'
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
                        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-5 lg:grid-cols-5 xl:grid-cols-5 gap-3">
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

                        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 lg:grid-cols-4 xl:grid-cols-4 gap-3">
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
BLADE

###############################################################################
# 2) Rewrite OFFERS CREATE (5 fields per row, no Charge Model, dynamic logic)
###############################################################################
cat > "$CREATE" << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ __('Create Offer') }}
        </h2>
    </x-slot>

    @php
        $countries              = $countries              ?? collect();
        $networks               = $networks               ?? collect();
        $networkMncs            = $networkMncs            ?? collect();
        $suppliers              = $suppliers              ?? collect();
        $connections            = $connections            ?? collect();
        $productTypeItems       = $productTypeItems       ?? collect();
        $knownHopsItems         = $knownHopsItems         ?? collect();
        $senderIdSupportedItems = $senderIdSupportedItems ?? collect();

        $connectionMeta = $connections->mapWithKeys(function ($c) {
            return [
                $c->id => [
                    'supplier_id'          => $c->supplier_id,
                    'product_type_label'   => $c->product_type,
                    'charge_type'          => $c->charge_type,
                ],
            ];
        });

        $productTypeByLabel = $productTypeItems->pluck('id', 'label');

        $chargeTypes = [
            'per_submit'    => 'Per Submit',
            'per_delivered' => 'Per Delivered',
        ];
    @endphp

    <div class="py-6">
        <div class="w-11/12 mx-auto">
            <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-gray-800">
                    {{ __('Create Offer') }}
                </h2>
                <a href="{{ route('offers.index') }}"
                   class="text-sm text-indigo-600 hover:text-indigo-800">
                    &larr; {{ __('Back to offers') }}
                </a>
            </div>

            <div class="bg-white shadow rounded-lg">
                <div class="px-4 py-3 sm:px-6 border-b">
                    <h3 class="text-sm font-semibold text-gray-700">
                        {{ __('Offer details') }}
                    </h3>
                </div>

                <div class="px-4 py-5 sm:px-6">
                    <form id="create-offer-form" method="POST" action="{{ route('offers.store') }}" class="space-y-5">
                        @csrf

                        <!-- Grid: 5 fields per row on md+ -->
                        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-5 lg:grid-cols-5 xl:grid-cols-5 gap-4">
                            <!-- Country -->
                            <div>
                                <label for="country_id" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Country') }}
                                </label>
                                <select name="country_id"
                                        id="country_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('Select country') }}</option>
                                    @foreach ($countries as $country)
                                        <option value="{{ $country->id }}" @selected(old('country_id') == $country->id)>
                                            {{ $country->name }}
                                        </option>
                                    @endforeach
                                </select>
                                @error('country_id')
                                    <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                                @enderror
                            </div>

                            <!-- Network -->
                            <div>
                                <label for="network_id" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Network') }}
                                </label>
                                <select name="network_id"
                                        id="network_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('Select network') }}</option>
                                    @foreach ($networks as $network)
                                        <option value="{{ $network->id }}"
                                                data-country-id="{{ $network->country_id ?? '' }}"
                                            @selected(old('network_id') == $network->id)>
                                            {{ $network->name }}
                                        </option>
                                    @endforeach
                                </select>
                                @error('network_id')
                                    <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                                @enderror
                            </div>

                            <!-- MNC / MCCMNC (from network_mncs) -->
                            <div>
                                <label for="network_mnc_id" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('MNC (MCCMNC)') }}
                                </label>
                                <select name="network_mnc_id"
                                        id="network_mnc_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('Select MNC') }}</option>
                                    @foreach ($networkMncs as $nm)
                                        @php
                                            $mncValue    = (string) $nm->mnc;
                                            $mncDisplay  = strlen($mncValue) === 1 ? ('0' . $mncValue) : $mncValue;
                                            $mccValue    = (string) $nm->mcc;
                                            $mccMncLabel = $mccValue . $mncDisplay;
                                        @endphp
                                        <option value="{{ $nm->id }}"
                                                data-network-id="{{ $nm->network_id }}"
                                                data-mcc="{{ $mccValue }}"
                                                data-mnc="{{ $mncDisplay }}"
                                            @selected(old('network_mnc_id') == $nm->id)>
                                            {{ $mccMncLabel }}
                                        </option>
                                    @endforeach
                                </select>
                                @error('network_mnc_id')
                                    <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                                @enderror
                            </div>

                            <!-- Supplier -->
                            <div>
                                <label for="supplier_id" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Supplier') }}
                                </label>
                                <select name="supplier_id"
                                        id="supplier_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('Select supplier') }}</option>
                                    @foreach ($suppliers as $supplier)
                                        <option value="{{ $supplier->id }}" @selected(old('supplier_id') == $supplier->id)>
                                            {{ $supplier->name }}
                                        </option>
                                    @endforeach
                                </select>
                                @error('supplier_id')
                                    <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                                @enderror
                            </div>

                            <!-- Connection -->
                            <div>
                                <label for="supplier_connection_id" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Connection') }}
                                </label>
                                <select name="supplier_connection_id"
                                        id="supplier_connection_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('Select connection') }}</option>
                                    @foreach ($connections as $connection)
                                        <option value="{{ $connection->id }}"
                                                data-supplier-id="{{ $connection->supplier_id }}"
                                                data-product-type-label="{{ $connection->product_type }}"
                                                data-charge-type="{{ $connection->charge_type }}"
                                            @selected(old('supplier_connection_id') == $connection->id)>
                                            {{ $connection->name }}
                                        </option>
                                    @endforeach
                                </select>
                                @error('supplier_connection_id')
                                    <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                                @enderror
                            </div>

                            <!-- Price -->
                            <div>
                                <label for="price" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Price (max 1.000000)') }}
                                </label>
                                <input type="number"
                                       name="price"
                                       id="price"
                                       step="0.000001"
                                       min="0"
                                       max="1"
                                       value="{{ old('price') }}"
                                       class="w-full rounded-md border-gray-300 text-xs sm:text-sm"
                                       required>
                                <p class="mt-1 text-[11px] text-gray-500">
                                    {{ __('Only values ≤ 1.000000 are allowed.') }}
                                </p>
                                @error('price')
                                    <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                                @enderror
                            </div>

                            <!-- Charge Type -->
                            <div>
                                <label for="charge_type" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Charge Type') }}
                                </label>
                                <select name="charge_type"
                                        id="charge_type"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('Select charge type') }}</option>
                                    @foreach ($chargeTypes as $value => $label)
                                        <option value="{{ $value }}" @selected(old('charge_type') === $value)>
                                            {{ $label }}
                                        </option>
                                    @endforeach
                                </select>
                                @error('charge_type')
                                    <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                                @enderror
                            </div>

                            <!-- Product Type -->
                            <div>
                                <label for="product_type_id" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Product Type') }}
                                </label>
                                <select name="product_type_id"
                                        id="product_type_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('Select product type') }}</option>
                                    @foreach ($productTypeItems as $item)
                                        <option value="{{ $item->id }}" @selected(old('product_type_id') == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                                @error('product_type_id')
                                    <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                                @enderror
                            </div>

                            <!-- Known Hops -->
                            <div>
                                <label for="known_hops_dropdown_item_id" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Known Hops') }}
                                </label>
                                <select name="known_hops_dropdown_item_id"
                                        id="known_hops_dropdown_item_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('Select') }}</option>
                                    @foreach ($knownHopsItems as $item)
                                        <option value="{{ $item->id }}" @selected(old('known_hops_dropdown_item_id') == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                                @error('known_hops_dropdown_item_id')
                                    <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                                @enderror
                            </div>

                            <!-- Sender ID Supported -->
                            <div>
                                <label for="sender_id_supported_dropdown_item_id" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Sender ID Supported') }}
                                </label>
                                <select name="sender_id_supported_dropdown_item_id"
                                        id="sender_id_supported_dropdown_item_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('Select') }}</option>
                                    @foreach ($senderIdSupportedItems as $item)
                                        <option value="{{ $item->id }}" @selected(old('sender_id_supported_dropdown_item_id') == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                                @error('sender_id_supported_dropdown_item_id')
                                    <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                                @enderror
                            </div>

                            <!-- MCCMNC (read-only) -->
                            <div>
                                <label for="mcc_mnc" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('MCCMNC') }}
                                </label>
                                <input type="text"
                                       name="mcc_mnc"
                                       id="mcc_mnc"
                                       value="{{ old('mcc_mnc') }}"
                                       class="w-full rounded-md border-gray-300 text-xs sm:text-sm bg-gray-50"
                                       readonly>
                                @error('mcc_mnc')
                                    <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                                @enderror
                            </div>

                            <!-- Exclusive -->
                            <div class="flex items-center mt-5">
                                <input type="checkbox"
                                       name="is_exclusive"
                                       id="is_exclusive"
                                       value="1"
                                       class="rounded border-gray-300"
                                       @checked(old('is_exclusive'))>
                                <label for="is_exclusive" class="ml-2 text-xs font-semibold text-gray-600">
                                    {{ __('Exclusive offer') }}
                                </label>
                            </div>
                        </div>

                        <!-- Hidden MCC/MNC fields (populated from selected MNC option) -->
                        <input type="hidden" name="mcc" id="mcc" value="{{ old('mcc') }}">
                        <input type="hidden" name="mnc" id="mnc" value="{{ old('mnc') }}">

                        <!-- Notes / comments -->
                        <div>
                            <label for="notes" class="block text-xs font-semibold text-gray-600 mb-1">
                                {{ __('Notes') }}
                            </label>
                            <textarea name="notes"
                                      id="notes"
                                      rows="3"
                                      class="w-full rounded-md border-gray-300 text-xs sm:text-sm">{{ old('notes') }}</textarea>
                            @error('notes')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        <div class="flex items-center justify-end gap-3 pt-2">
                            <a href="{{ route('offers.index') }}"
                               class="text-sm text-gray-500 hover:text-gray-700">
                                {{ __('Cancel') }}
                            </a>
                            <button type="submit"
                                    class="inline-flex items-center px-4 py-2 rounded-md bg-indigo-600 text-white text-sm font-medium hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                                {{ __('Save Offer') }}
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            // Elements
            const countrySelect    = document.getElementById('country_id');
            const networkSelect    = document.getElementById('network_id');
            const mncSelect        = document.getElementById('network_mnc_id');
            const supplierSelect   = document.getElementById('supplier_id');
            const connectionSelect = document.getElementById('supplier_connection_id');
            const productTypeInput = document.getElementById('product_type_id');
            const chargeTypeInput  = document.getElementById('charge_type');
            const priceInput       = document.getElementById('price');
            const mccInput         = document.getElementById('mcc');
            const mncInput         = document.getElementById('mnc');
            const mccMncInput      = document.getElementById('mcc_mnc');
            const form             = document.getElementById('create-offer-form');

            // Original options for filtering
            let allNetworkOptions = [];
            let allMncOptions     = [];
            let allConnectionOptions = [];

            if (networkSelect) {
                allNetworkOptions = Array.from(networkSelect.options);
            }
            if (mncSelect) {
                allMncOptions = Array.from(mncSelect.options);
            }
            if (connectionSelect) {
                allConnectionOptions = Array.from(connectionSelect.options);
            }

            // Data from backend
            const connectionMeta      = @json($connectionMeta);
            const productTypeByLabel  = @json($productTypeByLabel);

            function filterNetworksByCountry() {
                if (!countrySelect || !networkSelect || allNetworkOptions.length === 0) return;
                const selectedCountry = countrySelect.value || '';

                const current = networkSelect.value;
                networkSelect.innerHTML = '';
                const placeholder = document.createElement('option');
                placeholder.value = '';
                placeholder.textContent = '{{ __('Select network') }}';
                networkSelect.appendChild(placeholder);

                allNetworkOptions.forEach(function (opt) {
                    const cid = opt.getAttribute('data-country-id') || '';
                    if (opt.value === '' || selectedCountry === '' || cid === selectedCountry) {
                        networkSelect.appendChild(opt);
                    }
                });

                if (current && Array.from(networkSelect.options).some(o => o.value === current)) {
                    networkSelect.value = current;
                } else {
                    networkSelect.value = '';
                }

                // Reset MNC when country changes
                if (mncSelect) {
                    mncSelect.value = '';
                }
                updateMccMncFromSelected();
            }

            function filterMncsByNetwork() {
                if (!networkSelect || !mncSelect || allMncOptions.length === 0) return;
                const selectedNetwork = networkSelect.value || '';

                const current = mncSelect.value;
                mncSelect.innerHTML = '';
                const placeholder = document.createElement('option');
                placeholder.value = '';
                placeholder.textContent = '{{ __('Select MNC') }}';
                mncSelect.appendChild(placeholder);

                allMncOptions.forEach(function (opt) {
                    const nid = opt.getAttribute('data-network-id') || '';
                    if (opt.value === '' || selectedNetwork === '' || nid === selectedNetwork) {
                        mncSelect.appendChild(opt);
                    }
                });

                if (current && Array.from(mncSelect.options).some(o => o.value === current)) {
                    mncSelect.value = current;
                } else {
                    mncSelect.value = '';
                }

                updateMccMncFromSelected();
            }

            function updateMccMncFromSelected() {
                if (!mncSelect) return;
                const opt = mncSelect.options[mncSelect.selectedIndex];
                if (!opt || !opt.value) {
                    if (mccInput) mccInput.value = '';
                    if (mncInput) mncInput.value = '';
                    if (mccMncInput) mccMncInput.value = '';
                    return;
                }
                const mcc = opt.getAttribute('data-mcc') || '';
                const mnc = opt.getAttribute('data-mnc') || '';
                if (mccInput) mccInput.value = mcc;
                if (mncInput) mncInput.value = mnc;
                if (mccMncInput) mccMncInput.value = mcc + mnc;
            }

            function filterConnectionsBySupplier() {
                if (!supplierSelect || !connectionSelect || allConnectionOptions.length === 0) return;
                const selectedSupplier = supplierSelect.value || '';

                const current = connectionSelect.value;
                connectionSelect.innerHTML = '';
                const placeholder = document.createElement('option');
                placeholder.value = '';
                placeholder.textContent = '{{ __('Select connection') }}';
                connectionSelect.appendChild(placeholder);

                allConnectionOptions.forEach(function (opt) {
                    const sid = opt.getAttribute('data-supplier-id') || '';
                    if (opt.value === '' || selectedSupplier === '' || sid === selectedSupplier) {
                        connectionSelect.appendChild(opt);
                    }
                });

                if (current && Array.from(connectionSelect.options).some(o => o.value === current)) {
                    connectionSelect.value = current;
                } else {
                    connectionSelect.value = '';
                }

                applyConnectionDefaults();
            }

            function applyConnectionDefaults() {
                if (!connectionSelect) return;
                const connId = connectionSelect.value;
                if (!connId || !connectionMeta[connId]) return;

                const meta = connectionMeta[connId];

                // Product type from label -> dropdown item id
                if (meta.product_type_label && productTypeByLabel[meta.product_type_label] && productTypeInput) {
                    productTypeInput.value = String(productTypeByLabel[meta.product_type_label]);
                }

                // Charge type direct mapping
                if (meta.charge_type && chargeTypeInput) {
                    chargeTypeInput.value = meta.charge_type;
                }
            }

            // Price guard: must be ≤ 1
            if (form && priceInput) {
                form.addEventListener('submit', function (e) {
                    const v = parseFloat(priceInput.value);
                    if (!isNaN(v) && v > 1.0) {
                        e.preventDefault();
                        alert('Price must be ≤ 1.000000');
                        priceInput.focus();
                    }
                });
            }

            // Wire events
            if (countrySelect && networkSelect) {
                countrySelect.addEventListener('change', filterNetworksByCountry);
            }
            if (networkSelect && mncSelect) {
                networkSelect.addEventListener('change', filterMncsByNetwork);
            }
            if (mncSelect) {
                mncSelect.addEventListener('change', updateMccMncFromSelected);
            }
            if (supplierSelect && connectionSelect) {
                supplierSelect.addEventListener('change', filterConnectionsBySupplier);
            }
            if (connectionSelect) {
                connectionSelect.addEventListener('change', applyConnectionDefaults);
            }

            // Initial filters on load (for old() values)
            filterNetworksByCountry();
            filterMncsByNetwork();
            filterConnectionsBySupplier();
            updateMccMncFromSelected();
            applyConnectionDefaults();
        });
    </script>
</x-app-layout>
BLADE

###############################################################################
# 3) Clear compiled views
###############################################################################
echo "Clearing compiled views..."
if command -v docker >/dev/null 2>&1 && docker compose ps app >/dev/null 2>&1; then
  docker compose exec -T app php artisan view:clear || true
  docker compose exec -T app php artisan optimize:clear || true
elif command -v php >/dev/null 2>&1; then
  php artisan view:clear || true
  php artisan optimize:clear || true
fi

echo "fix_offers_views_v3.sh done."
