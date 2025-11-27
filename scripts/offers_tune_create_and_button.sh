#!/usr/bin/env bash

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_create_ui_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/resources/views/offers"

# Backup current views
if [ -f "resources/views/offers/index.blade.php" ]; then
  cp resources/views/offers/index.blade.php "${BACKUP_DIR}/resources/views/offers/" || echo "WARN: could not backup index.blade.php"
fi

if [ -f "resources/views/offers/create.blade.php" ]; then
  cp resources/views/offers/create.blade.php "${BACKUP_DIR}/resources/views/offers/" || echo "WARN: could not backup create.blade.php"
fi

#############################################
# 1) FIX index.blade.php CREATE BUTTON STYLE
#############################################

cat > resources/views/offers/index.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offers
        </h2>
    </x-slot>

    {{-- FULL WIDTH PAGE --}}
    <div class="py-6 w-full max-w-full px-2 sm:px-4 lg:px-6 mx-auto">
        @if (session('status'))
            <div class="mb-4 bg-green-50 border border-green-200 text-green-800 px-4 py-3 rounded text-sm">
                {{ session('status') }}
            </div>
        @endif

        {{-- Filters + Create Offer button --}}
        <div class="bg-white p-4 rounded-lg shadow mb-4 w-full">
            <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-gray-800">
                    Filters
                </h3>
                {{-- Create Offer button με πιο έντονο styling --}}
                <a href="{{ route('offers.create') }}"
                   class="inline-flex items-center gap-2 px-4 py-2 border border-green-700 text-sm font-semibold rounded-md shadow bg-green-600 text-white hover:bg-green-700 hover:shadow-md">
                    <span class="text-lg">＋</span>
                    <span>Create Offer</span>
                </a>
            </div>

            <form method="GET" action="{{ route('offers.index') }}" class="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-4 items-end">
                {{-- Country --}}
                <div>
                    <label for="country_id" class="block text-sm font-medium text-gray-700">Country</label>
                    <select id="country_id" name="country_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">All</option>
                        @foreach($countries as $country)
                            <option value="{{ $country->id }}" @selected(request('country_id') == $country->id)>
                                {{ $country->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Network --}}
                <div>
                    <label for="network_id" class="block text-sm font-medium text-gray-700">Network</label>
                    <select id="network_id" name="network_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">All</option>
                        @foreach($networks as $network)
                            <option value="{{ $network->id }}" @selected(request('network_id') == $network->id)>
                                {{ $network->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Supplier --}}
                <div>
                    <label for="supplier_id" class="block text-sm font-medium text-gray-700">Supplier</label>
                    <select id="supplier_id" name="supplier_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">All</option>
                        @foreach($suppliers as $supplier)
                            <option value="{{ $supplier->id }}" @selected(request('supplier_id') == $supplier->id)>
                                {{ $supplier->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Connection --}}
                <div>
                    <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">Connection</label>
                    <select id="supplier_connection_id" name="supplier_connection_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">All</option>
                        @foreach($connections as $connection)
                            <option value="{{ $connection->id }}" @selected(request('supplier_connection_id') == $connection->id)>
                                {{ $connection->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Product Type --}}
                <div>
                    <label for="product_type" class="block text-sm font-medium text-gray-700">Product Type</label>
                    <select id="product_type" name="product_type" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">All</option>
                        @foreach($productTypeFilterOptions as $productType)
                            <option value="{{ $productType }}" @selected(request('product_type') == $productType)>
                                {{ $productType }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Known Hops --}}
                <div>
                    <label for="known_hops_dropdown_item_id" class="block text-sm font-medium text-gray-700">Known Hops</label>
                    <select id="known_hops_dropdown_item_id" name="known_hops_dropdown_item_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">All</option>
                        @foreach($knownHopsFilterOptions as $item)
                            <option value="{{ $item->id }}" @selected(request('known_hops_dropdown_item_id') == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Sender ID Supported --}}
                <div>
                    <label for="sender_id_supported_dropdown_item_id" class="block text-sm font-medium text-gray-700">
                        Sender ID Supported
                    </label>
                    <select id="sender_id_supported_dropdown_item_id" name="sender_id_supported_dropdown_item_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">All</option>
                        @foreach($senderIdFilterOptions as $item)
                            <option value="{{ $item->id }}" @selected(request('sender_id_supported_dropdown_item_id') == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Charge Type --}}
                <div>
                    <label for="charge_type" class="block text-sm font-medium text-gray-700">Charge Type</label>
                    <select id="charge_type" name="charge_type" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">All</option>
                        @foreach($chargeTypeFilterOptions as $ct)
                            <option value="{{ $ct }}" @selected(request('charge_type') == $ct)>
                                {{ ucwords(str_replace('_', ' ', $ct)) }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Buttons --}}
                <div class="flex gap-2">
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                        Filter
                    </button>
                    <a href="{{ route('offers.index') }}"
                       class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm bg-white text-gray-700 hover:bg-gray-50">
                        Clear
                    </a>
                </div>
            </form>
        </div>

        {{-- Table with horizontal scroll --}}
        <div class="bg-white rounded-lg shadow overflow-x-auto w-full">
            <table class="min-w-max divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Country</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Network</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">MCC/MNC</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Supplier</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Connection</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Conn. Username</th>
                        <th class="px-3 py-2 text-right font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Price</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Product Type</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Known Hops</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Sender ID Supported</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Charge Type</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Last Edited</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Edited By</th>
                        <th class="px-3 py-2"></th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                    @forelse($offers as $offer)
                        <tr>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->country)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->network)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                @if($offer->mcc_mnc)
                                    {{ $offer->mcc_mnc }}
                                @elseif($offer->networkMnc)
                                    {{ $offer->networkMnc->mcc_mnc }}
                                @else
                                    -
                                @endif
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->supplier)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->connection)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->connection)->username ?? '-' }}
                            </td>
                            <td class="px-3 py-2 text-right whitespace-nowrap">
                                {{ $offer->price_trimmed ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ $offer->product_type_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ $offer->known_hops_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ $offer->sender_id_supported_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ $offer->charge_type_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->updated_at)->format('Y-m-d H:i') ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ $offer->updated_by_user_id ?? '-' }}
                            </td>
                            <td class="px-3 py-2 text-right whitespace-nowrap">
                                <a href="{{ route('offers.edit', $offer) }}"
                                   class="text-blue-600 hover:text-blue-900 text-sm">
                                    Edit
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="14" class="px-3 py-4 text-center text-gray-500">
                                No offers found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>

            <div class="px-3 py-3 border-t border-gray-200">
                {{ $offers->links() }}
            </div>
        </div>
    </div>
</x-app-layout>
BLADE

#############################################
# 2) CREATE OFFER FORM WITH MORE FUNCTIONALITY
#############################################

cat > resources/views/offers/create.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Create Offer
        </h2>
    </x-slot>

    <div class="py-6 w-full max-w-full px-2 sm:px-4 lg:px-6 mx-auto">
        @if ($errors->any())
            <div class="mb-4 bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded text-sm">
                <div class="font-semibold mb-1">Please fix the following errors:</div>
                <ul class="list-disc pl-5">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        @if (session('status'))
            <div class="mb-4 bg-green-50 border border-green-200 text-green-800 px-4 py-3 rounded text-sm">
                {{ session('status') }}
            </div>
        @endif

        <div class="bg-white p-6 rounded-lg shadow">
            <form method="POST" action="{{ route('offers.store') }}" class="grid grid-cols-1 md:grid-cols-2 gap-4">
                @csrf

                {{-- Country --}}
                <div>
                    <label for="country_id" class="block text-sm font-medium text-gray-700">Country</label>
                    <select id="country_id" name="country_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select country</option>
                        @foreach($countries as $country)
                            <option value="{{ $country->id }}" @selected(old('country_id', $offer->country_id) == $country->id)>
                                {{ $country->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Network (θα φιλτράρεται από τη χώρα με JS) --}}
                <div>
                    <label for="network_id" class="block text-sm font-medium text-gray-700">Network</label>
                    @php
                        // [Inference] Υποθέτουμε ότι κάθε Network έχει country_id
                    @endphp
                    <select id="network_id" name="network_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select network</option>
                        @foreach($networks as $network)
                            <option value="{{ $network->id }}"
                                    data-country-id="{{ $network->country_id ?? '' }}"
                                    @selected(old('network_id', $offer->network_id) == $network->id)>
                                {{ $network->name }}
                            </option>
                        @endforeach
                    </select>
                    <p class="mt-1 text-xs text-gray-500">
                        Networks will be filtered by selected country.
                    </p>
                </div>

                {{-- Supplier --}}
                <div>
                    <label for="supplier_id" class="block text-sm font-medium text-gray-700">Supplier</label>
                    <select id="supplier_id" name="supplier_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select supplier</option>
                        @foreach($suppliers as $supplier)
                            <option value="{{ $supplier->id }}" @selected(old('supplier_id', $offer->supplier_id) == $supplier->id)>
                                {{ $supplier->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Connection --}}
                <div>
                    <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">Connection</label>
                    <select id="supplier_connection_id" name="supplier_connection_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select connection</option>
                        @foreach($connections as $connection)
                            <option value="{{ $connection->id }}" @selected(old('supplier_connection_id', $offer->supplier_connection_id) == $connection->id)>
                                {{ $connection->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- MNC (φιλτράρεται από network με JS) --}}
                <div>
                    <label for="network_mnc_id" class="block text-sm font-medium text-gray-700">MNC</label>
                    <select id="network_mnc_id" name="network_mnc_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($networkMncs as $mnc)
                            <option value="{{ $mnc->id }}"
                                    data-network-id="{{ $mnc->network_id ?? '' }}"
                                    @selected(old('network_mnc_id', $offer->network_mnc_id) == $mnc->id)>
                                {{ $mnc->mcc_mnc }}
                            </option>
                        @endforeach
                    </select>
                    <p class="mt-1 text-xs text-gray-500">
                        Only MNCs of the selected network will remain visible.
                    </p>
                </div>

                {{-- Price --}}
                <div>
                    <label for="price" class="block text-sm font-medium text-gray-700">Price</label>
                    <input id="price"
                           name="price"
                           type="text"
                           value="{{ old('price', $offer->price) }}"
                           class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                           required>
                    <p class="mt-1 text-xs text-gray-500">
                        Will be stored trimmed (e.g. 0.03500 → 0.035).
                    </p>
                </div>

                {{-- Product Type (dropdown menu 1) --}}
                <div>
                    <label for="product_type_id" class="block text-sm font-medium text-gray-700">Product Type</label>
                    <select id="product_type_id" name="product_type_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($productTypeOptions as $item)
                            <option value="{{ $item->id }}" @selected(old('product_type_id', $selectedProductTypeId) == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Known Hops (dropdown menu 2) --}}
                <div>
                    <label for="known_hops_dropdown_item_id" class="block text-sm font-medium text-gray-700">Known Hops</label>
                    <select id="known_hops_dropdown_item_id" name="known_hops_dropdown_item_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($knownHopsOptions as $item)
                            <option value="{{ $item->id }}" @selected(old('known_hops_dropdown_item_id', $selectedKnownHopsId) == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Sender ID Supported (dropdown menu 3) --}}
                <div>
                    <label for="sender_id_supported_dropdown_item_id" class="block text-sm font-medium text-gray-700">Sender ID Supported</label>
                    <select id="sender_id_supported_dropdown_item_id" name="sender_id_supported_dropdown_item_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($senderIdOptions as $item)
                            <option value="{{ $item->id }}" @selected(old('sender_id_supported_dropdown_item_id', $selectedSenderIdSupportedId) == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Charge Type --}}
                <div>
                    <label for="charge_type" class="block text-sm font-medium text-gray-700">Charge Type</label>
                    <input id="charge_type"
                           name="charge_type"
                           type="text"
                           value="{{ old('charge_type', $offer->charge_type) }}"
                           class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                           placeholder="e.g. per_submit">
                </div>

                {{-- Is Exclusive --}}
                <div class="flex items-center mt-4">
                    <input id="is_exclusive"
                           name="is_exclusive"
                           type="checkbox"
                           value="1"
                           @checked(old('is_exclusive', $offer->is_exclusive)) 
                           class="h-4 w-4 text-indigo-600 border-gray-300 rounded">
                    <label for="is_exclusive" class="ml-2 block text-sm text-gray-700">
                        Exclusive
                    </label>
                </div>

                {{-- Effective Date --}}
                <div>
                    <label for="effective_date" class="block text-sm font-medium text-gray-700">Effective Date</label>
                    <input id="effective_date"
                           name="effective_date"
                           type="date"
                           value="{{ old('effective_date', optional($offer->effective_date)->format('Y-m-d')) }}"
                           class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                </div>

                {{-- Actions --}}
                <div class="mt-4 col-span-1 md:col-span-2 flex justify-end gap-2">
                    <a href="{{ route('offers.index') }}"
                       class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm bg-white text-gray-700 hover:bg-gray-50">
                        Cancel
                    </a>
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                        Save Offer
                    </button>
                </div>
            </form>
        </div>
    </div>

    {{-- Απλό JS για φιλτράρισμα Networks by Country και MNCs by Network --}}
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const countrySelect = document.getElementById('country_id');
            const networkSelect = document.getElementById('network_id');
            const mncSelect     = document.getElementById('network_mnc_id');

            function filterNetworksByCountry() {
                if (!countrySelect || !networkSelect) return;
                const countryId = countrySelect.value;
                Array.from(networkSelect.options).forEach(option => {
                    if (option.value === '') {
                        option.hidden = false;
                        return;
                    }
                    const optCountry = option.getAttribute('data-country-id') || '';
                    option.hidden = countryId && optCountry && optCountry !== countryId;
                });
                const selected = networkSelect.selectedOptions[0];
                if (selected && selected.hidden) {
                    networkSelect.value = '';
                }
                filterMncsByNetwork();
            }

            function filterMncsByNetwork() {
                if (!networkSelect || !mncSelect) return;
                const networkId = networkSelect.value;
                Array.from(mncSelect.options).forEach(option => {
                    if (option.value === '') {
                        option.hidden = false;
                        return;
                    }
                    const optNetwork = option.getAttribute('data-network-id') || '';
                    option.hidden = networkId && optNetwork && optNetwork !== networkId;
                });
                const selected = mncSelect.selectedOptions[0];
                if (selected && selected.hidden) {
                    mncSelect.value = '';
                }
            }

            if (countrySelect) {
                countrySelect.addEventListener('change', filterNetworksByCountry);
            }
            if (networkSelect) {
                networkSelect.addEventListener('change', filterMncsByNetwork);
            }

            // αρχικοί υπολογισμοί με old() values
            filterNetworksByCountry();
            filterMncsByNetwork();
        });
    </script>
</x-app-layout>
BLADE

echo "==> DONE. Backups stored at: ${BACKUP_DIR}"
