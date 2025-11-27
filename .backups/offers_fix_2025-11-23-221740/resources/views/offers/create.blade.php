<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">{{ __('Create Offer') }}</h2></x-slot>

    {{-- Guard definitions --}}
    @php
        $countries        = $countries        ?? collect();
        $networks         = $networks         ?? collect();
        $mncs             = $mncs             ?? collect();
        $suppliers        = $suppliers        ?? collect();
        $connections      = $connections      ?? collect();
        $productTypeItems = $productTypeItems ?? collect();
        $knownHopsItems   = $knownHopsItems   ?? collect();
        $senderIdItems    = $senderIdItems    ?? collect();
        $chargeModels     = $chargeModels     ?? collect();
    @endphp

    <div class="py-6">
        <div class="w-[90vw] mx-auto px-2 sm:px-4 lg:px-6">
            <div class="bg-white shadow rounded-lg p-6">
                <form id="offer_create_form" method="POST" action="{{ route('offers.store') }}">
                    @csrf
                    <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                        <!-- Country -->
                        <div>
                            <label for="country_id" class="block text-xs font-medium text-gray-700">{{ __('Country') }}</label>
                            <select name="country_id" id="country_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('Select country') }}</option>
                                @foreach($countries as $country)
                                    <option value="{{ $country->id }}" @selected(old('country_id') == $country->id)>{{ $country->name }}</option>
                                @endforeach
                            </select>
                            @error('country_id')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- Network -->
                        <div>
                            <label for="network_id" class="block text-xs font-medium text-gray-700">{{ __('Network') }}</label>
                            <select name="network_id" id="network_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('Select network') }}</option>
                                @foreach($networks as $network)
                                    <option value="{{ $network->id }}" data-country-id="{{ $network->country_id }}" @selected(old('network_id') == $network->id)>{{ $network->name }}</option>
                                @endforeach
                            </select>
                            @error('network_id')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- MNC -->
                        <div>
                            <label for="network_mnc_id" class="block text-xs font-medium text-gray-700">{{ __('MNC') }}</label>
                            <select name="network_mnc_id" id="network_mnc_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('Select MNC') }}</option>
                                @foreach($mncs as $mnc)
                                    <option value="{{ $mnc->id }}" data-network-id="{{ $mnc->network_id }}" data-mcc="{{ $mnc->mcc }}" data-mnc="{{ $mnc->mnc }}" @selected(old('network_mnc_id') == $mnc->id)>{{ $mnc->mnc }}</option>
                                @endforeach
                            </select>
                            @error('network_mnc_id')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- MCCMNC -->
                        <div>
                            <label for="mcc_mnc" class="block text-xs font-medium text-gray-700">{{ __('MCCMNC') }}</label>
                            <input type="text" id="mcc_mnc" name="mcc_mnc" value="{{ old('mcc_mnc') }}" readonly class="mt-1 block w-full rounded-md border-gray-300 text-sm bg-gray-100 text-gray-700">
                        </div>
                        <!-- Supplier -->
                        <div>
                            <label for="supplier_id" class="block text-xs font-medium text-gray-700">{{ __('Supplier') }}</label>
                            <select name="supplier_id" id="supplier_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('Select supplier') }}</option>
                                @foreach($suppliers as $supplier)
                                    <option value="{{ $supplier->id }}" @selected(old('supplier_id') == $supplier->id)>{{ $supplier->name }}</option>
                                @endforeach
                            </select>
                            @error('supplier_id')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- Connection -->
                        <div>
                            <label for="supplier_connection_id" class="block text-xs font-medium text-gray-700">{{ __('Connection') }}</label>
                            <select name="supplier_connection_id" id="supplier_connection_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('Select connection') }}</option>
                                @foreach($connections as $conn)
                                    <option value="{{ $conn->id }}" data-supplier-id="{{ $conn->supplier_id }}" data-product-type-id="{{ $conn->product_type_id }}" data-charge-type="{{ $conn->charge_type }}" data-username="{{ $conn->username }}" @selected(old('supplier_connection_id') == $conn->id)>{{ $conn->name }}</option>
                                @endforeach
                            </select>
                            @error('supplier_connection_id')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- Username -->
                        <div>
                            <label for="connection_username" class="block text-xs font-medium text-gray-700">{{ __('Username') }}</label>
                            <input type="text" id="connection_username" name="connection_username" value="{{ old('connection_username') }}" readonly class="mt-1 block w-full rounded-md border-gray-300 text-sm bg-gray-100 text-gray-700">
                        </div>
                        <!-- Product Type -->
                        <div>
                            <label for "product_type_id" class="block text-xs font-medium text-gray-700">{{ __('Product Type') }}</label>
                            <select name="product_type_id" id="product_type_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('Select product type') }}</option>
                                @foreach($productTypeItems as $item)
                                    <option value="{{ $item->id }}" @selected(old('product_type_id') == $item->id)>{{ $item->label }}</option>
                                @endforeach
                            </select>
                            @error('product_type_id')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- Known Hops -->
                        <div>
                            <label for "known_hops_dropdown_item_id" class="block text-xs font-medium text-gray-700">{{ __('Known Hops') }}</label>
                            <select name="known_hops_dropdown_item_id" id="known_hops_dropdown_item_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('Select known hops') }}</option>
                                @foreach($knownHopsItems as $item)
                                    <option value="{{ $item->id }}" @selected(old('known_hops_dropdown_item_id') == $item->id)>{{ $item->label }}</option>
                                @endforeach
                            </select>
                            @error('known_hops_dropdown_item_id')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- Sender Id Supported -->
                        <div>
                            <label for "sender_id_supported_dropdown_item_id" class="block text-xs font-medium text-gray-700">{{ __('Sender Id Supported') }}</label>
                            <select name="sender_id_supported_dropdown_item_id" id="sender_id_supported_dropdown_item_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('Select option') }}</option>
                                @foreach($senderIdItems as $item)
                                    <option value="{{ $item->id }}" @selected(old('sender_id_supported_dropdown_item_id') == $item->id)>{{ $item->label }}</option>
                                @endforeach
                            </select>
                            @error('sender_id_supported_dropdown_item_id')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- Charge Type -->
                        <div>
                            <label for="charge_type" class="block text-xs font-medium text-gray-700">{{ __('Charge Type') }}</label>
                            <select name="charge_type" id="charge_type" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('Select charge type') }}</option>
                                <option value="per_submit" @selected(old('charge_type') === 'per_submit')>{{ __('Per Submit') }}</option>
                                <option value="per_delivered" @selected(old('charge_type') === 'per_delivered')>{{ __('Per Delivered') }}</option>
                            </select>
                            @error('charge_type')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- Charge Model -->
                        <div>
                            <label for "charge_model_id" class="block text-xs font-medium text-gray-700">{{ __('Charge Model') }}</label>
                            <select name="charge_model_id" id="charge_model_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('Select charge model') }}</option>
                                @foreach($chargeModels as $model)
                                    <option value="{{ $model->id }}" @selected(old('charge_model_id') == $model->id)>{{ $model->name }}</option>
                                @endforeach
                            </select>
                            @error('charge_model_id')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- Is Exclusive -->
                        <div>
                            <label for="is_exclusive" class="block text-xs font-medium text-gray-700">{{ __('Is Exclusive') }}</label>
                            <select name="is_exclusive" id="is_exclusive" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="0" @selected(old('is_exclusive','0')=='0')>{{ __('No') }}</option>
                                <option value="1" @selected(old('is_exclusive')=='1')>{{ __('Yes') }}</option>
                            </select>
                            @error('is_exclusive')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- Price -->
                        <div>
                            <label for="price" class="block text-xs font-medium text-gray-700">{{ __('Price (EUR)') }}</label>
                            <input type="number" name="price" id="price" step="0.000001" min="0" max="0.999999"
                                   value="{{ old('price') }}"
                                   class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <p class="mt-1 text-[11px] text-gray-500">{{ __('Only prices below 1.000000 EUR (0.xxxxxx) are allowed.') }}</p>
                            @error('price')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                        <!-- Effective Date -->
                        <div>
                            <label for="effective_date" class="block text-xs font-medium text-gray-700">{{ __('Effective Date') }}</label>
                            <input type="date" name="effective_date" id="effective_date" value="{{ old('effective_date', now()->format('Y-m-d')) }}" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            @error('effective_date')<p class="mt-1 text-xs text-red-600">{{ $message }}</p>@enderror
                        </div>
                    </div>
                    <div class="mt-6 flex justify-end gap-2">
                        <a href="{{ route('offers.index') }}"
                           class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md text-xs font-semibold text-gray-700 bg-white hover:bg-gray-50">
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
            // Country→Network cascade
            const countrySel = document.getElementById('country_id');
            const networkSel = document.getElementById('network_id');
            const netOpts    = networkSel ? Array.from(networkSel.options) : [];
            if (countrySel && networkSel) {
                function updateNet() {
                    const cid = countrySel.value || '';
                    let cur   = networkSel.value;
                    let valid = false;
                    netOpts.forEach(opt => {
                        if (!opt.value) { opt.hidden = false; opt.disabled = false; return; }
                        const ocid = opt.dataset.countryId || '';
                        const show = !cid || ocid === cid;
                        opt.hidden = !show;
                        opt.disabled = !show;
                        if (show && opt.value === cur) valid = true;
                    });
                    if (!valid) networkSel.value = '';
                }
                countrySel.addEventListener('change', () => {
                    updateNet();
                    // reset mnc and mccmnc
                    const mncSel  = document.getElementById('network_mnc_id');
                    if (mncSel) mncSel.value = '';
                    const mccInp = document.getElementById('mcc_mnc');
                    if (mccInp) mccInp.value = '';
                });
                updateNet();
            }

            // Network→MNC cascade
            const mncSel = document.getElementById('network_mnc_id');
            const mncOpts = mncSel ? Array.from(mncSel.options) : [];
            if (networkSel && mncSel) {
                function updateMNC() {
                    const nid  = networkSel.value || '';
                    let cur    = mncSel.value;
                    let valid  = false;
                    mncOpts.forEach(opt => {
                        if (!opt.value) { opt.hidden = false; opt.disabled = false; return; }
                        const onid = opt.dataset.networkId || '';
                        const show = !nid || onid === nid;
                        opt.hidden = !show;
                        opt.disabled = !show;
                        if (show && opt.value === cur) valid = true;
                    });
                    if (!valid) mncSel.value = '';
                }
                networkSel.addEventListener('change', () => {
                    updateMNC();
                    const mccInp = document.getElementById('mcc_mnc');
                    if (mccInp) mccInp.value = '';
                });
                updateMNC();
            }

            // MNC→MCCMNC update
            const mccInput = document.getElementById('mcc_mnc');
            if (mncSel && mccInput) {
                function updateMCC() {
                    const opt = mncSel.options[mncSel.selectedIndex];
                    if (!opt) { mccInput.value = ''; return; }
                    const mcc = opt.dataset.mcc || '';
                    const mnc = opt.dataset.mnc || '';
                    mccInput.value = (mcc && mnc) ? (mcc + mnc) : '';
                }
                mncSel.addEventListener('change', updateMCC);
                updateMCC();
            }

            // Supplier→Connection and inheritance
            const suppSel = document.getElementById('supplier_id');
            const connSel = document.getElementById('supplier_connection_id');
            const connOpts = connSel ? Array.from(connSel.options) : [];
            const prodSel  = document.getElementById('product_type_id');
            const chgSel   = document.getElementById('charge_type');
            const userInp  = document.getElementById('connection_username');
            function filterConns() {
                const sid = suppSel.value || '';
                let cur   = connSel.value;
                let valid = false;
                connOpts.forEach(opt => {
                    if (!opt.value) { opt.hidden = false; opt.disabled = false; return; }
                    const oSid = opt.dataset.supplierId || '';
                    const show = !sid || oSid === sid;
                    opt.hidden  = !show;
                    opt.disabled = !show;
                    if (show && opt.value === cur) valid = true;
                });
                if (!valid) connSel.value = '';
            }
            function inheritConn() {
                const opt = connSel.options[connSel.selectedIndex];
                if (!opt) { return; }
                const ptype = opt.dataset.productTypeId || '';
                const ctype = opt.dataset.chargeType || '';
                const uname = opt.dataset.username || '';
                if (prodSel && ptype) prodSel.value = ptype;
                if (chgSel  && ctype) chgSel.value  = ctype;
                if (userInp) userInp.value = uname;
            }
            if (suppSel && connSel) {
                suppSel.addEventListener('change', () => {
                    filterConns();
                    connSel.value = '';
                    if (prodSel) prodSel.value = '';
                    if (chgSel)  chgSel.value  = '';
                    if (userInp) userInp.value = '';
                });
                connSel.addEventListener('change', inheritConn);
                filterConns();
                if (connSel.value) inheritConn();
            }

            // Enforce price <1 on change and submit
            const price = document.getElementById('price');
            if (price) {
                price.addEventListener('change', function () {
                    const val = parseFloat(price.value);
                    if (!isNaN(val) && val >= 1) {
                        alert('{{ __("Price must be less than 1.000000 EUR (0.xxxxxx).") }}');
                        price.value = '';
                        price.focus();
                    }
                });
            }
            const form = document.getElementById('offer_create_form');
            if (form) {
                form.addEventListener('submit', function (e) {
                    const val = parseFloat(price.value || '0');
                    if (!isNaN(val) && val >= 1) {
                        alert('{{ __("Price must be less than 1.000000 EUR (0.xxxxxx).") }}');
                        e.preventDefault();
                    }
                });
            }
        });
    </script>
</x-app-layout>
