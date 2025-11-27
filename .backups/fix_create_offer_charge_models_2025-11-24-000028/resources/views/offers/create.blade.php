<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ __('Create Offer') }}
        </h2>
    </x-slot>

    <style>
        .offers-page-container { width: 90vw; margin: 0 auto; }
        .offers-form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 1rem; }
    </style>

    @php
        // Load dropdown + lookup data directly
        $countries = DB::table('countries')->orderBy('name')->get();

        $networks = DB::table('networks')
            ->select('id', 'name', 'country_id')
            ->orderBy('name')
            ->get();

        $mncs = DB::table('network_mncs')
            ->select('id', 'network_id', 'mcc', 'mnc', 'mcc_mnc')
            ->orderBy('mcc_mnc')
            ->get();

        $suppliers = DB::table('suppliers')->orderBy('name')->get();

        $connections = DB::table('supplier_connections')
            ->select('id', 'supplier_id', 'name', 'username', 'product_type', 'charge_type')
            ->orderBy('name')
            ->get();

        $productTypeItems = DB::table('dropdown_items')
            ->where('dropdown_menu_id', 1)
            ->orderBy('label')
            ->get();

        $knownHopsItems = DB::table('dropdown_items')
            ->where('dropdown_menu_id', 2)
            ->orderBy('label')
            ->get();

        $senderIdItems = DB::table('dropdown_items')
            ->where('dropdown_menu_id', 3)
            ->orderBy('label')
            ->get();

        $chargeModels = DB::table('charge_models')
            ->select('id', 'name')
            ->orderBy('name')
            ->get();
    @endphp

    <div class="py-6 offers-page-container">
        <!-- widen page: remove max-w so it can use most of the screen -->
        <div class="mx-auto px-4 sm:px-6 lg:px-8">
            <div class="bg-white shadow rounded-lg">
                <div class="px-4 py-5 sm:p-6 border-b border-gray-200 flex items-center justify-between">
                    <h3 class="text-lg leading-6 font-medium text-gray-900">
                        {{ __('New Supplier Offer') }}
                    </h3>
                    <a href="{{ route('offers.index') }}"
                       class="inline-flex items-center px-3 py-1.5 border border-gray-300 rounded-md text-xs font-medium
                              text-gray-700 bg-white hover:bg-gray-50">
                        {{ __('Back to offers') }}
                    </a>
                </div>

                <form method="POST" action="{{ route('offers.store') }}" class="px-4 py-5 sm:p-6 space-y-6">
                    @csrf

                    <!-- many fields per row: 4–6 columns depending on width -->
                    <div class="offers-form-grid">
                        {{-- Country --}}
                        <div>
                            <label for="country_id" class="block text-xs font-medium text-gray-700">
                                {{ __('Country') }}
                            </label>
                            <select name="country_id" id="country_id" required
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                                <option value="">{{ __('Select country') }}</option>
                                @foreach ($countries as $country)
                                    <option value="{{ $country->id }}"
                                            @selected(old('country_id') == $country->id)>
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
                            <label for="network_id" class="block text-xs font-medium text-gray-700">
                                {{ __('Network') }}
                            </label>
                            <select name="network_id" id="network_id" required
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs">
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

                        {{-- MNC --}}
                        <div>
                            <label for="network_mnc_id" class="block text-xs font-medium text-gray-700">
                                {{ __('MNC') }}
                            </label>
                            <select name="network_mnc_id" id="network_mnc_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                                <option value="">{{ __('Select MNC') }}</option>
                                @foreach ($mncs as $mnc)
                                    @php
                                        $mncPadded = str_pad((string) $mnc->mnc, 2, '0', STR_PAD_LEFT);
                                    @endphp
                                    <option value="{{ $mnc->id }}"
                                            data-network-id="{{ $mnc->network_id ?? '' }}"
                                            data-mcc="{{ $mnc->mcc }}"
                                            data-mnc="{{ $mncPadded }}"
                                            @selected(old('network_mnc_id') == $mnc->id)>
                                        {{ $mncPadded }}
                                    </option>
                                @endforeach
                            </select>
                            @error('network_mnc_id')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- MCCMNC (read-only) --}}
                        <div>
                            <label for="mcc_mnc" class="block text-xs font-medium text-gray-700">
                                {{ __('MCCMNC') }}
                            </label>
                            <input type="text" name="mcc_mnc" id="mcc_mnc"
                                   value="{{ old('mcc_mnc') }}"
                                   readonly
                                   class="mt-1 block w-full rounded-md border-gray-300 text-xs bg-gray-100 font-mono" />
                            @error('mcc_mnc')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Supplier --}}
                        <div>
                            <label for="supplier_id" class="block text-xs font-medium text-gray-700">
                                {{ __('Supplier') }}
                            </label>
                            <select name="supplier_id" id="supplier_id" required
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs">
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

                        {{-- Connection --}}
                        <div>
                            <label for="supplier_connection_id" class="block text-xs font-medium text-gray-700">
                                {{ __('Connection') }}
                            </label>
                            <select name="supplier_connection_id" id="supplier_connection_id" required
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                                <option value="">{{ __('Select connection') }}</option>
                                @foreach ($connections as $conn)
                                    <option value="{{ $conn->id }}"
                                            data-supplier-id="{{ $conn->supplier_id ?? '' }}"
                                            data-product-type="{{ $conn->product_type ?? '' }}"
                                            data-charge-type="{{ $conn->charge_type ?? '' }}"
                                            data-username="{{ $conn->username ?? '' }}"
                                            @selected(old('supplier_connection_id') == $conn->id)>
                                        {{ $conn->name }}
                                    </option>
                                @endforeach
                            </select>
                            @error('supplier_connection_id')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Username (read-only) --}}
                        <div>
                            <label for="connection_username" class="block text-xs font-medium text-gray-700">
                                {{ __('Username') }}
                            </label>
                            <input type="text" id="connection_username"
                                   value=""
                                   readonly
                                   class="mt-1 block w-full rounded-md border-gray-300 text-xs bg-gray-100 font-mono" />
                        </div>

                        {{-- Product Type --}}
                        <div>
                            <label for="product_type_id" class="block text-xs font-medium text-gray-700">
                                {{ __('Product Type') }}
                            </label>
                            <select name="product_type_id" id="product_type_id" required
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                                <option value="">{{ __('Select product type') }}</option>
                                @foreach ($productTypeItems as $item)
                                    <option value="{{ $item->id }}"
                                            data-label="{{ $item->label }}"
                                            @selected(old('product_type_id') == $item->id)>
                                        {{ $item->label }}
                                    </option>
                                @endforeach
                            </select>
                            @error('product_type_id')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Known Hops --}}
                        <div>
                            <label for="known_hops_dropdown_item_id" class="block text-xs font-medium text-gray-700">
                                {{ __('Known Hops') }}
                            </label>
                            <select name="known_hops_dropdown_item_id" id="known_hops_dropdown_item_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs">
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

                        {{-- Sender Id Supported --}}
                        <div>
                            <label for="sender_id_supported_dropdown_item_id" class="block text-xs font-medium text-gray-700">
                                {{ __('Sender Id Supported') }}
                            </label>
                            <select name="sender_id_supported_dropdown_item_id" id="sender_id_supported_dropdown_item_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs">
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

                        {{-- Charge Type --}}
                        <div>
                            <label for="charge_type" class="block text-xs font-medium text-gray-700">
                                {{ __('Charge Type') }}
                            </label>
                            <select name="charge_type" id="charge_type" required
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs">
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
                            <label for="charge_model_id" class="block text-xs font-medium text-gray-700">
                                {{ __('Charge Model') }}
                            </label>
                            <select name="charge_model_id" id="charge_model_id" required
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs">
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
                            <label for="is_exclusive" class="block text-xs font-medium text-gray-700">
                                {{ __('Is Exclusive') }}
                            </label>
                            <select name="is_exclusive" id="is_exclusive" required
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                                <option value="0" @selected(old('is_exclusive', '0') === '0')>{{ __('No') }}</option>
                                <option value="1" @selected(old('is_exclusive') === '1')>{{ __('Yes') }}</option>
                            </select>
                            @error('is_exclusive')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Price --}}
                        <div>
                            <label for="price" class="block text-xs font-medium text-gray-700">
                                {{ __('Price (EUR)') }}
                            </label>
                            <input type="number" step="0.000001" min="0" max="0.999999"
                                   name="price" id="price"
                                   value="{{ old('price') }}"
                                   required
                                   class="mt-1 block w-full rounded-md border-gray-300 text-xs" />
                            <p class="mt-1 text-xs text-gray-500">
                                {{ __('Only values < 1.000000 are allowed (0.xxxxxx).') }}
                            </p>
                            @error('price')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Effective Date --}}
                        <div>
                            <label for="effective_date" class="block text-xs font-medium text-gray-700">
                                {{ __('Effective Date') }}
                            </label>
                            <input type="date" name="effective_date" id="effective_date"
                                   value="{{ old('effective_date') }}"
                                   class="mt-1 block w-full rounded-md border-gray-300 text-xs" />
                            @error('effective_date')
                                <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                            @enderror
                        </div>
                    </div>

                    <div class="flex justify-end space-x-3">
                        <a href="{{ route('offers.index') }}"
                           class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md text-xs font-semibold
                                  text-gray-700 bg-white hover:bg-gray-50">
                            {{ __('Cancel') }}
                        </a>
                        <button type="submit"
                                class="inline-flex items-center px-4 py-2 bg-indigo-600 border border-transparent rounded-md
                                       text-xs font-semibold text-white uppercase tracking-widest hover:bg-indigo-700
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
            const countrySelect    = document.getElementById('country_id');
            const networkSelect    = document.getElementById('network_id');
            const mncSelect        = document.getElementById('network_mnc_id');
            const mccMncInput      = document.getElementById('mcc_mnc');
            const supplierSelect   = document.getElementById('supplier_id');
            const connectionSelect = document.getElementById('supplier_connection_id');
            const usernameInput    = document.getElementById('connection_username');
            const productTypeSelect = document.getElementById('product_type_id');
            const chargeTypeSelect  = document.getElementById('charge_type');
            const priceInput        = document.getElementById('price');

            const networkOptions   = networkSelect ? Array.from(networkSelect.options) : [];
            const mncOptions       = mncSelect ? Array.from(mncSelect.options) : [];
            const connectionOptions = connectionSelect ? Array.from(connectionSelect.options) : [];

            function updateNetworks() {
                if (!countrySelect || !networkSelect) return;
                const cid = countrySelect.value || '';
                const current = networkSelect.value;
                let currentValid = false;

                networkOptions.forEach(opt => {
                    if (!opt.value) {
                        opt.hidden = false;
                        opt.disabled = false;
                        return;
                    }
                    const ocid = opt.dataset.countryId || '';
                    const show = !cid || ocid === cid;
                    opt.hidden = !show;
                    opt.disabled = !show;
                    if (show && opt.value === current) {
                        currentValid = true;
                    }
                });

                if (!currentValid) {
                    networkSelect.value = '';
                }
            }

            function updateMncs() {
                if (!networkSelect || !mncSelect) return;
                const nid = networkSelect.value || '';
                const current = mncSelect.value;
                let currentValid = false;

                mncOptions.forEach(opt => {
                    if (!opt.value) {
                        opt.hidden = false;
                        opt.disabled = false;
                        return;
                    }
                    const onid = opt.dataset.networkId || '';
                    const show = !nid || onid === nid;
                    opt.hidden = !show;
                    opt.disabled = !show;
                    if (show && opt.value === current) {
                        currentValid = true;
                    }
                });

                if (!currentValid) {
                    mncSelect.value = '';
                }
                updateMccMnc();
            }

            function updateMccMnc() {
                if (!mncSelect || !mccMncInput) return;
                const opt = mncSelect.selectedOptions[0];
                if (!opt || !opt.value) {
                    mccMncInput.value = '';
                    return;
                }
                const mcc = (opt.dataset.mcc || '').trim();
                const mnc = (opt.dataset.mnc || '').trim(); // already padded from Blade
                if (mcc && mnc) {
                    mccMncInput.value = mcc + mnc;
                } else {
                    mccMncInput.value = '';
                }
            }

            function filterConnectionsBySupplier() {
                if (!supplierSelect || !connectionSelect) return;
                const sid = supplierSelect.value || '';
                const current = connectionSelect.value;
                let currentValid = false;

                connectionOptions.forEach(opt => {
                    if (!opt.value) {
                        opt.hidden = false;
                        opt.disabled = false;
                        return;
                    }
                    const osid = opt.dataset.supplierId || '';
                    const show = !sid || osid === sid;
                    opt.hidden = !show;
                    opt.disabled = !show;
                    if (show && opt.value === current) {
                        currentValid = true;
                    }
                });

                if (!currentValid) {
                    connectionSelect.value = '';
                    inheritConnectionAttributes();
                }
            }

            function inheritConnectionAttributes() {
                if (!connectionSelect) return;
                const opt = connectionSelect.selectedOptions[0];
                if (!opt || !opt.value) {
                    if (usernameInput) usernameInput.value = '';
                    return;
                }

                const productTypeLabel = opt.dataset.productType || '';
                const chargeType       = opt.dataset.chargeType || '';
                const username         = opt.dataset.username || '';

                if (usernameInput) {
                    usernameInput.value = username;
                }

                if (productTypeSelect && productTypeLabel) {
                    let matched = false;
                    Array.from(productTypeSelect.options).forEach(o => {
                        const label = (o.dataset.label || o.textContent || '').trim();
                        if (label === productTypeLabel) {
                            o.selected = true;
                            matched = true;
                        }
                    });
                    if (!matched) {
                        productTypeSelect.value = '';
                    }
                }

                if (chargeTypeSelect && chargeType) {
                    chargeTypeSelect.value = chargeType;
                }
            }

            function enforcePriceLimit() {
                if (!priceInput) return;
                const v = parseFloat(priceInput.value);
                if (!isNaN(v) && v >= 1) {
                    priceInput.setCustomValidity('Price must be lower than 1.000000 EUR (0.xxxxxx).');
                } else {
                    priceInput.setCustomValidity('');
                }
            }

            if (countrySelect) {
                countrySelect.addEventListener('change', function () {
                    updateNetworks();
                    updateMncs();
                });
            }
            if (networkSelect) {
                networkSelect.addEventListener('change', updateMncs);
            }
            if (mncSelect) {
                mncSelect.addEventListener('change', updateMccMnc);
            }
            if (supplierSelect) {
                supplierSelect.addEventListener('change', filterConnectionsBySupplier);
            }
            if (connectionSelect) {
                connectionSelect.addEventListener('change', inheritConnectionAttributes);
            }
            if (priceInput) {
                priceInput.addEventListener('input', enforcePriceLimit);
            }

            // Initial cascade on load
            updateNetworks();
            updateMncs();
            filterConnectionsBySupplier();
            inheritConnectionAttributes();
            enforcePriceLimit();
        });
    </script>
</x-app-layout>
