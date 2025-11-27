<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ __('Create Offer') }}
        </h2>
    </x-slot>

    <div class="py-6">
        <div class="w-[90vw] mx-auto px-2 sm:px-4 lg:px-6">
            <div class="bg-white shadow rounded-lg p-6">
                <form id="offer_create_form" method="POST" action="{{ route('offers.store') }}">
                    @csrf

                    <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">

                        {{-- Country --}}
                        <div>
                            <label for="country_id" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Country') }}
                            </label>
                            <select name="country_id" id="country_id"
                                    class="w-full rounded-md border-gray-300 shadow-sm text-sm">
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

                        {{-- Network --}}
                        <div>
                            <label for="network_id" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Network') }}
                            </label>
                            <select name="network_id" id="network_id"
                                    class="w-full rounded-md border-gray-300 shadow-sm text-sm">
                                <option value="">{{ __('Select network') }}</option>
                                @foreach ($networks as $network)
                                    <option value="{{ $network->id }}"
                                            data-country-id="{{ $network->country_id }}"
                                            @selected(old('network_id') == $network->id)>
                                        {{ $network->name }}
                                    </option>
                                @endforeach
                            </select>
                            @error('network_id')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- MNC (network MNC) --}}
                        <div>
                            <label for="network_mnc_id" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('MNC') }}
                            </label>
                            <select name="network_mnc_id" id="network_mnc_id"
                                    class="w-full rounded-md border-gray-300 shadow-sm text-sm">
                                <option value="">{{ __('Select MNC') }}</option>
                                @foreach ($mncs ?? [] as $mnc)
                                    <option value="{{ $mnc->id }}"
                                            data-network-id="{{ $mnc->network_id }}"
                                            data-mcc="{{ $mnc->mcc }}"
                                            data-mnc="{{ $mnc->mnc }}"
                                            @selected(old('network_mnc_id') == $mnc->id)>
                                        {{ $mnc->mnc }}
                                    </option>
                                @endforeach
                            </select>
                            @error('network_mnc_id')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- MCCMNC readonly --}}
                        <div>
                            <label for="mcc_mnc" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('MCCMNC') }}
                            </label>
                            <input type="text" id="mcc_mnc" name="mcc_mnc"
                                   value="{{ old('mcc_mnc') }}"
                                   readonly
                                   class="w-full rounded-md border-gray-300 shadow-sm text-sm bg-gray-100 text-gray-700" />
                        </div>

                        {{-- Supplier --}}
                        <div>
                            <label for="supplier_id" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Supplier') }}
                            </label>
                            <select name="supplier_id" id="supplier_id"
                                    class="w-full rounded-md border-gray-300 shadow-sm text-sm">
                                <option value="">{{ __('Select supplier') }}</option>
                                @foreach ($suppliers as $supplier)
                                    <option value="{{ $supplier->id }}"
                                            @selected(old('supplier_id') == $supplier->id)>
                                        {{ $supplier->name }}
                                    </option>
                                @endforeach
                            </select>
                            @error('supplier_id')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Connection (filtered by supplier) --}}
                        <div>
                            <label for="supplier_connection_id" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Connection') }}
                            </label>
                            <select name="supplier_connection_id" id="supplier_connection_id"
                                    class="w-full rounded-md border-gray-300 shadow-sm text-sm">
                                <option value="">{{ __('Select connection') }}</option>
                                @foreach ($connections as $connection)
                                    <option value="{{ $connection->id }}"
                                            data-supplier-id="{{ $connection->supplier_id }}"
                                            data-product-type-id="{{ $connection->product_type_id }}"
                                            data-charge-type="{{ $connection->charge_type }}"
                                            data-username="{{ $connection->username }}"
                                            @selected(old('supplier_connection_id') == $connection->id)>
                                        {{ $connection->name }}
                                    </option>
                                @endforeach
                            </select>
                            @error('supplier_connection_id')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Username readonly --}}
                        <div>
                            <label for="connection_username" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Username') }}
                            </label>
                            <input type="text" id="connection_username" name="connection_username"
                                   value="{{ old('connection_username') }}"
                                   readonly
                                   class="w-full rounded-md border-gray-300 shadow-sm text-sm bg-gray-100 text-gray-700" />
                        </div>

                        {{-- Product Type (dropdown menu 1) --}}
                        <div>
                            <label for="product_type_id" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Product Type') }}
                            </label>
                            <select name="product_type_id" id="product_type_id"
                                    class="w-full rounded-md border-gray-300 shadow-sm text-sm">
                                <option value="">{{ __('Select product type') }}</option>
                                @foreach ($productTypeItems as $item)
                                    <option value="{{ $item->id }}"
                                            @selected(old('product_type_id') == $item->id)>
                                        {{ $item->label }}
                                    </option>
                                @endforeach
                            </select>
                            @error('product_type_id')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Known Hops (dropdown menu 2) --}}
                        <div>
                            <label for="known_hops_dropdown_item_id" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Known Hops') }}
                            </label>
                            <select name="known_hops_dropdown_item_id" id="known_hops_dropdown_item_id"
                                    class="w-full rounded-md border-gray-300 shadow-sm text-sm">
                                <option value="">{{ __('Select known hops') }}</option>
                                @foreach ($knownHopsItems as $item)
                                    <option value="{{ $item->id }}"
                                            @selected(old('known_hops_dropdown_item_id') == $item->id)>
                                        {{ $item->label }}
                                    </option>
                                @endforeach
                            </select>
                            @error('known_hops_dropdown_item_id')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Sender Id Supported (dropdown menu 3) --}}
                        <div>
                            <label for="sender_id_supported_dropdown_item_id" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Sender Id Supported') }}
                            </label>
                            <select name="sender_id_supported_dropdown_item_id" id="sender_id_supported_dropdown_item_id"
                                    class="w-full rounded-md border-gray-300 shadow-sm text-sm">
                                <option value="">{{ __('Select option') }}</option>
                                @foreach ($senderIdItems as $item)
                                    <option value="{{ $item->id }}"
                                            @selected(old('sender_id_supported_dropdown_item_id') == $item->id)>
                                        {{ $item->label }}
                                    </option>
                                @endforeach
                            </select>
                            @error('sender_id_supported_dropdown_item_id')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Charge Type (inherit from connection but editable) --}}
                        <div>
                            <label for="charge_type" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Charge Type') }}
                            </label>
                            <select name="charge_type" id="charge_type"
                                    class="w-full rounded-md border-gray-300 shadow-sm text-sm">
                                <option value="">{{ __('Select charge type') }}</option>
                                <option value="per_submit" @selected(old('charge_type') === 'per_submit')>
                                    {{ __('Per Submit') }}
                                </option>
                                <option value="per_delivered" @selected(old('charge_type') === 'per_delivered')>
                                    {{ __('Per Delivered') }}
                                </option>
                            </select>
                            @error('charge_type')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Charge Model --}}
                        <div>
                            <label for="charge_model_id" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Charge Model') }}
                            </label>
                            <select name="charge_model_id" id="charge_model_id"
                                    class="w-full rounded-md border-gray-300 shadow-sm text-sm">
                                <option value="">{{ __('Select charge model') }}</option>
                                @foreach ($chargeModels as $model)
                                    <option value="{{ $model->id }}"
                                            @selected(old('charge_model_id') == $model->id)>
                                        {{ $model->name }}
                                    </option>
                                @endforeach
                            </select>
                            @error('charge_model_id')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Is Exclusive --}}
                        <div>
                            <label for="is_exclusive" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Is Exclusive') }}
                            </label>
                            <select name="is_exclusive" id="is_exclusive"
                                    class="w-full rounded-md border-gray-300 shadow-sm text-sm">
                                <option value="0" @selected(old('is_exclusive', '0') == '0')>{{ __('No') }}</option>
                                <option value="1" @selected(old('is_exclusive') == '1')>{{ __('Yes') }}</option>
                            </select>
                            @error('is_exclusive')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Price (must be < 1 EUR) --}}
                        <div>
                            <label for="price" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Price (EUR)') }}
                            </label>
                            <input type="number"
                                   name="price"
                                   id="price"
                                   step="0.000001"
                                   min="0"
                                   max="0.999999"
                                   value="{{ old('price') }}"
                                   class="w-full rounded-md border-gray-300 shadow-sm text-sm" />
                            <p class="mt-1 text-[11px] text-gray-500">
                                {{ __('Only prices below 1.000000 EUR are allowed (0.xxxxxx).') }}
                            </p>
                            @error('price')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Effective Date --}}
                        <div>
                            <label for="effective_date" class="block text-xs font-medium text-gray-700 mb-1">
                                {{ __('Effective Date') }}
                            </label>
                            <input type="date"
                                   name="effective_date"
                                   id="effective_date"
                                   value="{{ old('effective_date', now()->format('Y-m-d')) }}"
                                   class="w-full rounded-md border-gray-300 shadow-sm text-sm" />
                            @error('effective_date')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>
                    </div>

                    <div class="mt-6 flex justify-end gap-2">
                        <a href="{{ route('offers.index') }}"
                           class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md text-xs font-semibold
                                  text-gray-700 bg-white hover:bg-gray-50">
                            {{ __('Cancel') }}
                        </a>

                        <button type="submit"
                                class="inline-flex items-center px-4 py-2 bg-indigo-600 border border-transparent rounded-md
                                       font-semibold text-xs text-white uppercase tracking-widest hover:bg-indigo-700
                                       focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                            {{ __('Save Offer') }}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const countrySelect   = document.getElementById('country_id');
            const networkSelect   = document.getElementById('network_id');
            const mncSelect       = document.getElementById('network_mnc_id');
            const mccMncInput     = document.getElementById('mcc_mnc');

            const supplierSelect  = document.getElementById('supplier_id');
            const connectionSelect = document.getElementById('supplier_connection_id');
            const productTypeSelect = document.getElementById('product_type_id');
            const chargeTypeSelect  = document.getElementById('charge_type');
            const usernameInput     = document.getElementById('connection_username');

            const priceInput       = document.getElementById('price');
            const form             = document.getElementById('offer_create_form');

            // Country -> Network cascade
            if (countrySelect && networkSelect) {
                const allNetworkOptions = Array.from(networkSelect.options);
                function filterNetworks() {
                    const cId = countrySelect.value || '';
                    let currentValue = networkSelect.value;
                    let currentValid = false;

                    allNetworkOptions.forEach(opt => {
                        if (!opt.value) {
                            opt.hidden = false;
                            opt.disabled = false;
                            return;
                        }
                        const optCountry = opt.dataset.countryId || '';
                        const show = !cId || optCountry === cId;
                        opt.hidden  = !show;
                        opt.disabled = !show;
                        if (show && opt.value === currentValue) {
                            currentValid = true;
                        }
                    });

                    if (!currentValid) {
                        networkSelect.value = '';
                    }
                }
                countrySelect.addEventListener('change', () => {
                    filterNetworks();
                    // Reset MNC and MCCMNC when country changes
                    if (mncSelect) mncSelect.value = '';
                    if (mccMncInput) mccMncInput.value = '';
                });
                filterNetworks();
            }

            // Network -> MNC cascade
            if (networkSelect && mncSelect) {
                const allMncOptions = Array.from(mncSelect.options);
                function filterMncs() {
                    const nId = networkSelect.value || '';
                    let currentValue = mncSelect.value;
                    let currentValid = false;

                    allMncOptions.forEach(opt => {
                        if (!opt.value) {
                            opt.hidden = false;
                            opt.disabled = false;
                            return;
                        }
                        const optNetworkId = opt.dataset.networkId || '';
                        const show = !nId || optNetworkId === nId;
                        opt.hidden  = !show;
                        opt.disabled = !show;
                        if (show && opt.value === currentValue) {
                            currentValid = true;
                        }
                    });

                    if (!currentValid) {
                        mncSelect.value = '';
                    }
                }
                networkSelect.addEventListener('change', () => {
                    filterMncs();
                    if (mccMncInput) mccMncInput.value = '';
                });
                filterMncs();
            }

            // MNC -> MCCMNC field
            if (mncSelect && mccMncInput) {
                function updateMccMnc() {
                    const opt = mncSelect.options[mncSelect.selectedIndex];
                    if (!opt || !opt.dataset) {
                        mccMncInput.value = '';
                        return;
                    }
                    const mcc = opt.dataset.mcc || '';
                    const mnc = opt.dataset.mnc || '';
                    mccMncInput.value = mcc && mnc ? (mcc + mnc) : '';
                }
                mncSelect.addEventListener('change', updateMccMnc);
                updateMccMnc();
            }

            // Supplier -> Connections filter + inherit product type, charge type & username
            if (supplierSelect && connectionSelect) {
                const allConnectionOptions = Array.from(connectionSelect.options);

                function filterConnections() {
                    const supplierId = supplierSelect.value || '';
                    let currentValue = connectionSelect.value;
                    let currentValid = false;

                    allConnectionOptions.forEach(opt => {
                        if (!opt.value) {
                            opt.hidden = false;
                            opt.disabled = false;
                            return;
                        }
                        const optSupplierId = opt.dataset.supplierId || '';
                        const show = !supplierId || optSupplierId === supplierId;
                        opt.hidden  = !show;
                        opt.disabled = !show;
                        if (show && opt.value === currentValue) {
                            currentValid = true;
                        }
                    });

                    if (!currentValid) {
                        connectionSelect.value = '';
                    }
                }

                function updateFromConnection() {
                    const opt = connectionSelect.options[connectionSelect.selectedIndex];
                    if (!opt) return;

                    const productTypeId = opt.dataset.productTypeId || '';
                    const chargeType    = opt.dataset.chargeType || '';
                    const username      = opt.dataset.username || '';

                    if (productTypeSelect && productTypeId) {
                        productTypeSelect.value = productTypeId;
                    }
                    if (chargeTypeSelect && chargeType) {
                        chargeTypeSelect.value = chargeType;
                    }
                    if (usernameInput) {
                        usernameInput.value = username;
                    }
                }

                supplierSelect.addEventListener('change', () => {
                    filterConnections();
                    connectionSelect.value = '';
                    if (productTypeSelect) productTypeSelect.value = '';
                    if (chargeTypeSelect)  chargeTypeSelect.value = '';
                    if (usernameInput)     usernameInput.value = '';
                });

                connectionSelect.addEventListener('change', updateFromConnection);

                filterConnections();
                if (connectionSelect.value) {
                    updateFromConnection();
                }
            }

            // Enforce price < 1 EUR on submit
            if (form && priceInput) {
                form.addEventListener('submit', function (e) {
                    const raw = priceInput.value;
                    if (!raw) return;

                    const val = parseFloat(raw);
                    if (!Number.isNaN(val) && val >= 1) {
                        alert('{{ __('Price must be less than 1.000000 EUR (0.xxxxxx).') }}');
                        e.preventDefault();
                    }
                });
            }
        });
    </script>
</x-app-layout>
