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

        @php
            // [Inference] Χρησιμοποιούμε distinct charge_type από υπάρχουσες offers για το dropdown
            $chargeTypeOptions = \App\Models\SupplierOffer::query()
                ->select('charge_type')
                ->whereNotNull('charge_type')
                ->distinct()
                ->orderBy('charge_type')
                ->pluck('charge_type');
        @endphp

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

                {{-- Network (shortlist από χώρα + label με MCC/MNC) --}}
                <div>
                    <label for="network_id" class="block text-sm font-medium text-gray-700">Network</label>
                    <select id="network_id" name="network_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select network</option>
                        @foreach($networks as $network)
                            @php
                                $networkMncsForNetwork = $networkMncs->where('network_id', $network->id);
                                $mccMncList = $networkMncsForNetwork->pluck('mcc_mnc')->unique()->values();
                            @endphp
                            <option value="{{ $network->id }}"
                                    data-country-id="{{ $network->country_id ?? '' }}"
                                    @selected(old('network_id', $offer->network_id) == $network->id)>
                                {{ $network->name }}
                                @if($mccMncList->isNotEmpty())
                                    — {{ $mccMncList->join(', ') }}
                                @endif
                            </option>
                        @endforeach
                    </select>
                    <p class="mt-1 text-xs text-gray-500">
                        Networks are filtered by the selected country.
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

                {{-- Connection (θα οδηγεί τα defaults σε Product Type + Charge Type) --}}
                <div>
                    <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">Connection</label>
                    <select id="supplier_connection_id" name="supplier_connection_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select connection</option>
                        @foreach($connections as $connection)
                            <option value="{{ $connection->id }}"
                                    data-charge-type="{{ $connection->charge_type ?? '' }}"
                                    data-product-type-id="{{ $connection->product_type_id ?? ($connection->product_type_dropdown_item_id ?? '') }}"
                                    @selected(old('supplier_connection_id', $offer->supplier_connection_id) == $connection->id)>
                                {{ $connection->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- MNC (shortlist by network) --}}
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

                {{-- Charge Type (dropdown αντί για text) --}}
                <div>
                    <label for="charge_type" class="block text-sm font-medium text-gray-700">Charge Type</label>
                    <select id="charge_type" name="charge_type" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($chargeTypeOptions as $ct)
                            <option value="{{ $ct }}" @selected(old('charge_type', $offer->charge_type) == $ct)>
                                {{ ucwords(str_replace('_', ' ', $ct)) }}
                            </option>
                        @endforeach
                    </select>
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

    {{-- JS: filter Networks by Country, MNCs by Network, και defaults από Connection --}}
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const countrySelect    = document.getElementById('country_id');
            const networkSelect    = document.getElementById('network_id');
            const mncSelect        = document.getElementById('network_mnc_id');
            const connectionSelect = document.getElementById('supplier_connection_id');
            const productTypeSelect = document.getElementById('product_type_id');
            const chargeTypeSelect  = document.getElementById('charge_type');

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

            function applyConnectionDefaults() {
                if (!connectionSelect) return;
                const selected = connectionSelect.selectedOptions[0];
                if (!selected) return;

                const productTypeId = selected.getAttribute('data-product-type-id') || '';
                const chargeTypeVal = selected.getAttribute('data-charge-type') || '';

                if (productTypeSelect && productTypeId) {
                    productTypeSelect.value = productTypeId;
                }

                if (chargeTypeSelect && chargeTypeVal) {
                    const opt = Array.from(chargeTypeSelect.options).find(o => o.value === chargeTypeVal);
                    if (opt) {
                        chargeTypeSelect.value = chargeTypeVal;
                    }
                }
            }

            if (countrySelect) {
                countrySelect.addEventListener('change', filterNetworksByCountry);
            }
            if (networkSelect) {
                networkSelect.addEventListener('change', filterMncsByNetwork);
            }
            if (connectionSelect) {
                connectionSelect.addEventListener('change', applyConnectionDefaults);
            }

            // Αρχικά apply (για old() values / προεπιλογές)
            filterNetworksByCountry();
            filterMncsByNetwork();
            applyConnectionDefaults();
        });
    </script>
</x-app-layout>
