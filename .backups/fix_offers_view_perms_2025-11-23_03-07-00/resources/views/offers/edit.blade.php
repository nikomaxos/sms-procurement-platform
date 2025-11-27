<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Edit Offer
        </h2>
    </x-slot>

    <div class="py-6 max-w-5xl mx-auto sm:px-6 lg:px-8">
        <div class="bg-white shadow-sm rounded-lg p-6">
            <form method="POST" action="{{ route('offers.update', $offer) }}" class="space-y-6">
                @csrf
                @method('PUT')

                {{-- Country / Network / MNC --}}
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label for="country_id" class="block text-sm font-medium text-gray-700">
                            Country
                        </label>
                        <select id="country_id" name="country_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($countries as $country)
                                <option value="{{ $country->id }}"
                                    @selected(old('country_id', $offer->country_id) == $country->id)>
                                    {{ $country->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('country_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="network_id" class="block text-sm font-medium text-gray-700">
                            Network
                        </label>
                        <select id="network_id" name="network_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($networks as $network)
                                <option value="{{ $network->id }}"
                                        data-country-id="{{ $network->country_id }}"
                                    @selected(old('network_id', $offer->network_id) == $network->id)>
                                    {{ $network->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('network_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="network_mnc_id" class="block text-sm font-medium text-gray-700">
                            MNC
                        </label>
                        <select id="network_mnc_id" name="network_mnc_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($networkMncs as $mnc)
                                <option value="{{ $mnc->id }}"
                                        data-network-id="{{ $mnc->network_id }}"
                                        data-mcc="{{ $mnc->mcc }}"
                                        data-mnc="{{ $mnc->mnc }}"
                                        data-mccmnc="{{ $mnc->mcc_mnc }}"
                                    @selected(old('network_mnc_id', $offer->network_mnc_id) == $mnc->id)>
                                    {{ $mnc->mnc }} ({{ $mnc->mcc_mnc }})
                                </option>
                            @endforeach
                        </select>
                        @error('network_mnc_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                {{-- MCCMNC readonly / Price / Effective --}}
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label for="mccmnc_display" class="block text-sm font-medium text-gray-700">
                            MCCMNC
                        </label>
                        <input type="text" id="mccmnc_display" readonly
                               class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm text-sm"
                               value="{{ $offer->mcc_mnc }}">
                    </div>

                    <div>
                        <label for="price" class="block text-sm font-medium text-gray-700">
                            Price
                        </label>
                        <input type="text" id="price" name="price"
                               value="{{ old('price', $offer->price) }}"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                        @error('price')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="effective_date" class="block text-sm font-medium text-gray-700">
                            Effective Date
                        </label>
                        <input type="date" id="effective_date" name="effective_date"
                               value="{{ old('effective_date', optional($offer->effective_date)->format('Y-m-d')) }}"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                        @error('effective_date')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                {{-- Supplier / Connection / Username --}}
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label for="supplier_id" class="block text-sm font-medium text-gray-700">
                            Supplier
                        </label>
                        <select id="supplier_id" name="supplier_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($suppliers as $supplier)
                                <option value="{{ $supplier->id }}"
                                    @selected(old('supplier_id', $offer->supplier_id) == $supplier->id)>
                                    {{ $supplier->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('supplier_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">
                            Connection
                        </label>
                        <select id="supplier_connection_id" name="supplier_connection_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($connections as $conn)
                                <option value="{{ $conn->id }}"
                                        data-supplier-id="{{ $conn->supplier_id }}"
                                        data-username="{{ $conn->username }}"
                                        data-product-type="{{ $conn->product_type }}"
                                        data-charge-type="{{ $conn->charge_type }}"
                                    @selected(old('supplier_connection_id', $offer->supplier_connection_id) == $conn->id)>
                                    {{ $conn->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('supplier_connection_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="username_display" class="block text-sm font-medium text-gray-700">
                            Username
                        </label>
                        <input type="text" id="username_display" readonly
                               class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm text-sm"
                               value="{{ $offer->connection?->username }}">
                    </div>
                </div>

                {{-- Product Type / Known Hops / Sender Id / Charge Type --}}
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                    <div>
                        <label for="product_type" class="block text-sm font-medium text-gray-700">
                            Product Type
                        </label>
                        <select id="product_type" name="product_type"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($productTypeOptions as $value => $label)
                                <option value="{{ $value }}"
                                    @selected(old('product_type', $offer->product_type) == $value)>
                                    {{ $label }}
                                </option>
                            @endforeach
                        </select>
                        @error('product_type')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="known_hops" class="block text-sm font-medium text-gray-700">
                            Known Hops
                        </label>
                        <select id="known_hops" name="known_hops"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($knownHopsOptions as $value => $label)
                                <option value="{{ $value }}"
                                    @selected(old('known_hops', $offer->known_hops) == $value)>
                                    {{ $label }}
                                </option>
                            @endforeach
                        </select>
                        @error('known_hops')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="sender_id_supported" class="block text-sm font-medium text-gray-700">
                            Sender Id Supported
                        </label>
                        <select id="sender_id_supported" name="sender_id_supported"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($senderIdOptions as $value => $label)
                                <option value="{{ $value }}"
                                    @selected(old('sender_id_supported', $offer->sender_id_supported) == $value)>
                                    {{ $label }}
                                </option>
                            @endforeach
                        </select>
                        @error('sender_id_supported')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="charge_type" class="block text-sm font-medium text-gray-700">
                            Charge Type
                        </label>
                        <select id="charge_type" name="charge_type"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            <option value="per_submit" @selected(old('charge_type', $offer->charge_type) === 'per_submit')>
                                Per Submit
                            </option>
                            <option value="per_delivered" @selected(old('charge_type', $offer->charge_type) === 'per_delivered')>
                                Per Delivered
                            </option>
                        </select>
                        @error('charge_type')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                {{-- Route Type / Is Exclusive --}}
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                    <div>
                        <label for="route_type" class="block text-sm font-medium text-gray-700">
                            Route Type
                        </label>
                        <input type="text" id="route_type" name="route_type"
                               value="{{ old('route_type', $offer->route_type) }}"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                        @error('route_type')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div class="flex items-center mt-6">
                        <input type="checkbox" id="is_exclusive" name="is_exclusive" value="1"
                               class="h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
                               @checked(old('is_exclusive', $offer->is_exclusive))>
                        <label for="is_exclusive" class="ml-2 text-sm text-gray-700">
                            Is Exclusive
                        </label>
                    </div>
                </div>

                <div class="flex justify-between">
                    <form method="POST" action="{{ route('offers.destroy', $offer) }}"
                          onsubmit="return confirm('Delete this offer?');">
                        @csrf
                        @method('DELETE')
                        <button type="submit"
                                class="inline-flex items-center px-4 py-2 border border-red-300 rounded-md text-sm text-red-700 bg-white hover:bg-red-50">
                            Delete
                        </button>
                    </form>

                    <div class="flex space-x-2">
                        <a href="{{ route('offers.index') }}"
                           class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md text-sm text-gray-700 bg-white hover:bg-gray-50">
                            Cancel
                        </a>
                        <button type="submit"
                                class="inline-flex items-center px-4 py-2 border border-transparent rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700">
                            Update Offer
                        </button>
                    </div>
                </div>
            </form>
        </div>
    </div>

    <script>
        (function () {
            const countrySelect = document.getElementById('country_id');
            const networkSelect = document.getElementById('network_id');
            const mncSelect = document.getElementById('network_mnc_id');
            const mccmncDisplay = document.getElementById('mccmnc_display');
            const supplierSelect = document.getElementById('supplier_id');
            const connSelect = document.getElementById('supplier_connection_id');
            const usernameDisplay = document.getElementById('username_display');

            function filterNetworksByCountry() {
                const countryId = countrySelect.value;
                Array.from(networkSelect.options).forEach(opt => {
                    if (!opt.value) return;
                    const cid = opt.getAttribute('data-country-id');
                    opt.hidden = !!countryId && cid !== countryId;
                });
            }

            function filterMncsByNetwork() {
                const networkId = networkSelect.value;
                Array.from(mncSelect.options).forEach(opt => {
                    if (!opt.value) return;
                    const nid = opt.getAttribute('data-network-id');
                    opt.hidden = !!networkId && nid !== networkId;
                });
            }

            function updateMccMncDisplay() {
                const opt = mncSelect.selectedOptions[0];
                if (opt && opt.value) {
                    mccmncDisplay.value = opt.getAttribute('data-mccmnc') || '';
                } else {
                    mccmncDisplay.value = '';
                }
            }

            function filterConnectionsBySupplier() {
                const supplierId = supplierSelect.value;
                Array.from(connSelect.options).forEach(opt => {
                    if (!opt.value) return;
                    const sid = opt.getAttribute('data-supplier-id');
                    opt.hidden = !!supplierId && sid !== supplierId;
                });
                updateConnectionDependentFields();
            }

            function updateConnectionDependentFields() {
                const opt = connSelect.selectedOptions[0];
                if (opt && opt.value) {
                    usernameDisplay.value = opt.getAttribute('data-username') || '';
                } else {
                    usernameDisplay.value = '';
                }
            }

            if (countrySelect && networkSelect && mncSelect) {
                countrySelect.addEventListener('change', function () {
                    filterNetworksByCountry();
                    filterMncsByNetwork();
                    updateMccMncDisplay();
                });
                networkSelect.addEventListener('change', function () {
                    filterMncsByNetwork();
                    updateMccMncDisplay();
                });
                mncSelect.addEventListener('change', updateMccMncDisplay);
                filterNetworksByCountry();
                filterMncsByNetwork();
                updateMccMncDisplay();
            }

            if (supplierSelect && connSelect && usernameDisplay) {
                supplierSelect.addEventListener('change', function () {
                    filterConnectionsBySupplier();
                });
                connSelect.addEventListener('change', updateConnectionDependentFields);
                filterConnectionsBySupplier();
            }
        })();
    </script>
</x-app-layout>
