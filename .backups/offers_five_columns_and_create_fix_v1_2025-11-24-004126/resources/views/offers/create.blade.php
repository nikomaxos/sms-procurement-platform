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
