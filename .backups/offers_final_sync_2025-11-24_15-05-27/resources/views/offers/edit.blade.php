<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ __('Edit Offer') }}
        </h2>
    </x-slot>

    @php
        $productTypeItems = $productTypeItems ?? collect();
        $knownHopsItems   = $knownHopsItems   ?? collect();
        $senderIdItems    = $senderIdItems    ?? collect();
        $countries        = $countries        ?? collect();
        $networks         = $networks         ?? collect();
        $networkMncs      = $networkMncs      ?? collect();
        $suppliers        = $suppliers        ?? collect();
        $connections      = $connections      ?? collect();

        $networksForJs = $networks->map(fn($n) => [
            'id'         => $n->id,
            'name'       => $n->name,
            'country_id' => $n->country_id,
        ])->values();

        $networkMncsForJs = $networkMncs->map(fn($nm) => [
            'id'         => $nm->id,
            'network_id' => $nm->network_id,
            'mcc'        => $nm->mcc,
            'mnc'        => $nm->mnc,
            'mcc_mnc'    => $nm->mcc_mnc,
        ])->values();

        $connectionsForJs = $connections->map(fn($c) => [
            'id'           => $c->id,
            'supplier_id'  => $c->supplier_id,
            'name'         => $c->name,
            'product_type' => $c->product_type,
            'charge_type'  => $c->charge_type,
        ])->values();

        $productTypeItemsForJs = $productTypeItems->map(fn($i) => [
            'id'    => $i->id,
            'label' => $i->label,
        ])->values();

        $currentCountryId      = old('country_id', $offer->country_id);
        $currentNetworkId      = old('network_id', $offer->network_id);
        $currentNetworkMncId   = old('network_mnc_id', $offer->network_mnc_id);
        $currentSupplierId     = old('supplier_id', $offer->supplier_id);
        $currentConnectionId   = old('supplier_connection_id', $offer->supplier_connection_id);
        $currentProductTypeId  = old('product_type_dropdown_item_id', $offer->product_type_dropdown_item_id);
        $currentKnownHopsId    = old('known_hops_dropdown_item_id', $offer->known_hops_dropdown_item_id);
        $currentSenderIdItemId = old('sender_id_supported_dropdown_item_id', $offer->sender_id_supported_dropdown_item_id);
        $currentChargeType     = old('charge_type', $offer->charge_type);
        $currentPrice          = old('price', $offer->price);
        $currentExclusive      = old('is_exclusive', $offer->is_exclusive ? '1' : '0');
        $currentEffectiveDate  = old('effective_date', optional($offer->effective_date)->format('Y-m-d'));
        $currentMcc            = $offer->mcc;
        $currentMnc            = sprintf('%02d', (int) $offer->mnc); // pad like 01
        $currentMccMnc         = $offer->mcc_mnc ?: ($currentMcc . $currentMnc);
    @endphp

    <div class="py-6">
        <div class="mx-auto w-11/12 max-w-5xl sm:px-4 lg:px-6">
            <div class="bg-white shadow-sm sm:rounded-lg">
                <div class="px-4 py-4 border-b border-gray-200 flex items-center justify-between">
                    <div>
                        <h3 class="text-lg leading-6 font-medium text-gray-900">
                            {{ __('Edit Offer') }}
                        </h3>
                        <p class="mt-1 text-xs text-gray-500">
                            {{ __('Update the details of this offer. Changing the connection will refresh product type and charge type based on the connection settings.') }}
                        </p>
                    </div>
                    <a href="{{ route('offers.index') }}" class="text-xs text-indigo-600 hover:underline">
                        {{ __('Back to offers') }}
                    </a>
                </div>

                <div class="px-4 py-5">
                    @if ($errors->any())
                        <div class="mb-4 rounded-md bg-red-50 p-3 border border-red-200">
                            <div class="text-xs font-semibold text-red-700 mb-1">
                                {{ __('There were some problems with your input:') }}
                            </div>
                            <ul class="list-disc list-inside text-xs text-red-600">
                                @foreach ($errors->all() as $error)
                                    <li>{{ $error }}</li>
                                @endforeach
                            </ul>
                        </div>
                    @endif

                    <form method="POST" action="{{ route('offers.update', $offer) }}">
                        @csrf
                        @method('PUT')

                        {{-- 5-per-row layout --}}
                        <div class="grid grid-cols-1 md:grid-cols-5 gap-4">

                            {{-- Country --}}
                            <div>
                                <label for="country_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('Country') }}
                                </label>
                                <select
                                    name="country_id"
                                    id="country_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('Select country') }}</option>
                                    @foreach ($countries as $country)
                                        <option value="{{ $country->id }}" @selected($currentCountryId == $country->id)>
                                            {{ $country->name }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- Network --}}
                            <div>
                                <label for="network_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('Network') }}
                                </label>
                                <select
                                    name="network_id"
                                    id="network_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                    data-current-network="{{ $currentNetworkId }}"
                                >
                                    <option value="">{{ __('Select network') }}</option>
                                    @foreach ($networks as $network)
                                        <option value="{{ $network->id }}" @selected($currentNetworkId == $network->id)>
                                            {{ $network->name }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- MNC selector --}}
                            <div>
                                <label for="network_mnc_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('MCC/MNC') }}
                                </label>
                                <select
                                    name="network_mnc_id"
                                    id="network_mnc_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                    data-current-mnc="{{ $currentNetworkMncId }}"
                                >
                                    <option value="">{{ __('Select MCC/MNC') }}</option>
                                    @foreach ($networkMncs as $nm)
                                        <option value="{{ $nm->id }}" @selected($currentNetworkMncId == $nm->id)>
                                            {{ $nm->mcc_mnc }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- Supplier --}}
                            <div>
                                <label for="supplier_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('Supplier') }}
                                </label>
                                <select
                                    name="supplier_id"
                                    id="supplier_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('Select supplier') }}</option>
                                    @foreach ($suppliers as $supplier)
                                        <option value="{{ $supplier->id }}" @selected($currentSupplierId == $supplier->id)>
                                            {{ $supplier->name }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- Connection --}}
                            <div>
                                <label for="supplier_connection_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('Connection') }}
                                </label>
                                <select
                                    name="supplier_connection_id"
                                    id="supplier_connection_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                    data-current-connection="{{ $currentConnectionId }}"
                                >
                                    <option value="">{{ __('Select supplier first') }}</option>
                                </select>
                            </div>

                            {{-- MCC (read-only display) --}}
                            <div>
                                <label class="block text-xs font-medium text-gray-700">
                                    {{ __('MCC') }}
                                </label>
                                <input
                                    type="text"
                                    id="mcc_display"
                                    class="mt-1 block w-full rounded-md border-gray-200 bg-gray-50 text-xs text-gray-700"
                                    value="{{ $currentMcc }}"
                                    readonly
                                >
                            </div>

                            {{-- MNC (padded read-only display) --}}
                            <div>
                                <label class="block text-xs font-medium text-gray-700">
                                    {{ __('MNC') }}
                                </label>
                                <input
                                    type="text"
                                    id="mnc_display"
                                    class="mt-1 block w-full rounded-md border-gray-200 bg-gray-50 text-xs text-gray-700"
                                    value="{{ $currentMnc }}"
                                    readonly
                                >
                            </div>

                            {{-- MCCMNC (read-only display) --}}
                            <div>
                                <label class="block text-xs font-medium text-gray-700">
                                    {{ __('MCCMNC') }}
                                </label>
                                <input
                                    type="text"
                                    id="mcc_mnc_display"
                                    class="mt-1 block w-full rounded-md border-gray-200 bg-gray-50 text-xs text-gray-700"
                                    value="{{ $currentMccMnc }}"
                                    readonly
                                >
                            </div>

                            {{-- Price --}}
                            <div>
                                <label for="price" class="block text-xs font-medium text-gray-700">
                                    {{ __('Price (0.xxxxxx)') }}
                                </label>
                                <input
                                    type="number"
                                    name="price"
                                    id="price"
                                    step="0.000001"
                                    min="0"
                                    max="0.999999"
                                    value="{{ $currentPrice }}"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                            </div>

                            {{-- Charge type (display + hidden for submit) --}}
                            <div>
                                <label class="block text-xs font-medium text-gray-700">
                                    {{ __('Charge type') }}
                                </label>
                                <input
                                    type="text"
                                    id="charge_type_display"
                                    class="mt-1 block w-full rounded-md border-gray-200 bg-gray-50 text-xs text-gray-700"
                                    value="{{ $currentChargeType }}"
                                    readonly
                                >
                                <input type="hidden" name="charge_type" id="charge_type" value="{{ $currentChargeType }}">
                            </div>

                            {{-- Product type --}}
                            <div>
                                <label for="product_type_dropdown_item_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('Product type') }}
                                </label>
                                <select
                                    name="product_type_dropdown_item_id"
                                    id="product_type_dropdown_item_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('Select product type') }}</option>
                                    @foreach ($productTypeItems as $item)
                                        <option value="{{ $item->id }}" @selected($currentProductTypeId == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- Known hops --}}
                            <div>
                                <label for="known_hops_dropdown_item_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('Known hops') }}
                                </label>
                                <select
                                    name="known_hops_dropdown_item_id"
                                    id="known_hops_dropdown_item_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('Select') }}</option>
                                    @foreach ($knownHopsItems as $item)
                                        <option value="{{ $item->id }}" @selected($currentKnownHopsId == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- Sender ID supported --}}
                            <div>
                                <label for="sender_id_supported_dropdown_item_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('Sender ID supported') }}
                                </label>
                                <select
                                    name="sender_id_supported_dropdown_item_id"
                                    id="sender_id_supported_dropdown_item_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('Select') }}</option>
                                    @foreach ($senderIdItems as $item)
                                        <option value="{{ $item->id }}" @selected($currentSenderIdItemId == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- Exclusive --}}
                            <div>
                                <label for="is_exclusive" class="block text-xs font-medium text-gray-700">
                                    {{ __('Exclusive') }}
                                </label>
                                <select
                                    name="is_exclusive"
                                    id="is_exclusive"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="0" @selected($currentExclusive === '0')>{{ __('No') }}</option>
                                    <option value="1" @selected($currentExclusive === '1')>{{ __('Yes') }}</option>
                                </select>
                            </div>

                            {{-- Effective date --}}
                            <div>
                                <label for="effective_date" class="block text-xs font-medium text-gray-700">
                                    {{ __('Effective date') }}
                                </label>
                                <input
                                    type="date"
                                    name="effective_date"
                                    id="effective_date"
                                    value="{{ $currentEffectiveDate }}"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                            </div>

                        </div>

                        <div class="mt-6 flex items-center justify-end gap-3">
                            <a
                                href="{{ route('offers.index') }}"
                                class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-md text-xs font-medium text-gray-700 bg-white hover:bg-gray-50"
                            >
                                {{ __('Cancel') }}
                            </a>
                            <button
                                type="submit"
                                class="inline-flex items-center px-4 py-2 border border-transparent rounded-md text-xs font-semibold text-white bg-indigo-600 hover:bg-indigo-700"
                            >
                                {{ __('Save changes') }}
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const networks     = @json($networksForJs);
            const networkMncs  = @json($networkMncsForJs);
            const connections  = @json($connectionsForJs);
            const productTypes = @json($productTypeItemsForJs);

            const countrySelect    = document.getElementById('country_id');
            const networkSelect    = document.getElementById('network_id');
            const mncSelect        = document.getElementById('network_mnc_id');
            const supplierSelect   = document.getElementById('supplier_id');
            const connectionSelect = document.getElementById('supplier_connection_id');

            const productTypeSelect = document.getElementById('product_type_dropdown_item_id');
            const chargeTypeHidden  = document.getElementById('charge_type');
            const chargeTypeDisplay = document.getElementById('charge_type_display');

            const mccField    = document.getElementById('mcc_display');
            const mncField    = document.getElementById('mnc_display');
            const mccmncField = document.getElementById('mcc_mnc_display');

            const currentNetworkId    = networkSelect?.dataset.currentNetwork || '';
            const currentNetworkMncId = mncSelect?.dataset.currentMnc || '';
            const currentConnectionId = connectionSelect?.dataset.currentConnection || '';

            function rebuildNetworks() {
                if (!countrySelect || !networkSelect) return;

                const countryId = countrySelect.value || '';
                const current   = networkSelect.value || currentNetworkId;

                const options = [];
                const placeholder = document.createElement('option');
                placeholder.value = '';
                placeholder.textContent = '{{ __('Select network') }}';
                options.push(placeholder);

                networks.forEach(n => {
                    if (!countryId || String(n.country_id) === String(countryId)) {
                        const opt = document.createElement('option');
                        opt.value = n.id;
                        opt.textContent = n.name;
                        if (String(n.id) === String(current)) {
                            opt.selected = true;
                        }
                        options.push(opt);
                    }
                });

                networkSelect.innerHTML = '';
                options.forEach(o => networkSelect.appendChild(o));
            }

            function rebuildMncs() {
                if (!networkSelect || !mncSelect) return;

                const networkId = networkSelect.value || '';
                const current   = mncSelect.value || currentNetworkMncId;

                const options = [];
                const placeholder = document.createElement('option');
                placeholder.value = '';
                placeholder.textContent = '{{ __('Select MCC/MNC') }}';
                options.push(placeholder);

                networkMncs.forEach(nm => {
                    if (!networkId || String(nm.network_id) === String(networkId)) {
                        const opt = document.createElement('option');
                        opt.value = nm.id;
                        opt.textContent = nm.mcc_mnc;
                        if (String(nm.id) === String(current)) {
                            opt.selected = true;
                        }
                        options.push(opt);
                    }
                });

                mncSelect.innerHTML = '';
                options.forEach(o => mncSelect.appendChild(o));

                applyNetworkMncDetails();
            }

            function applyNetworkMncDetails() {
                if (!mncSelect) return;
                const id = mncSelect.value || currentNetworkMncId;
                const nm = networkMncs.find(x => String(x.id) === String(id));

                if (!nm) {
                    if (mccField) mccField.value = '';
                    if (mncField) mncField.value = '';
                    if (mccmncField) mccmncField.value = '';
                    return;
                }

                const mncPadded = nm.mnc.toString().padStart(2, '0');

                if (mccField)    mccField.value    = nm.mcc;
                if (mncField)    mncField.value    = mncPadded;
                if (mccmncField) mccmncField.value = nm.mcc.toString() + mncPadded;
            }

            function rebuildConnections() {
                if (!supplierSelect || !connectionSelect) return;

                const supplierId = supplierSelect.value || '';
                const current    = connectionSelect.value || currentConnectionId;

                const options = [];
                const placeholder = document.createElement('option');
                placeholder.value = '';
                placeholder.textContent = supplierId
                    ? '{{ __('Select connection') }}'
                    : '{{ __('Select supplier first') }}';
                options.push(placeholder);

                connectionSelect.disabled = !supplierId;

                if (supplierId) {
                    connections.forEach(c => {
                        if (String(c.supplier_id) === String(supplierId)) {
                            const opt = document.createElement('option');
                            opt.value = c.id;
                            opt.textContent = c.name;
                            if (String(c.id) === String(current)) {
                                opt.selected = true;
                            }
                            options.push(opt);
                        }
                    });
                }

                connectionSelect.innerHTML = '';
                options.forEach(o => connectionSelect.appendChild(o));

                applyConnectionDefaults();
            }

            function applyConnectionDefaults() {
                if (!connectionSelect) return;

                const connId = connectionSelect.value || currentConnectionId;
                const conn = connections.find(c => String(c.id) === String(connId));

                if (!conn) {
                    if (chargeTypeDisplay) chargeTypeDisplay.value = '';
                    if (chargeTypeHidden)  chargeTypeHidden.value  = '';
                    return;
                }

                if (conn.charge_type) {
                    if (chargeTypeDisplay) chargeTypeDisplay.value = conn.charge_type;
                    if (chargeTypeHidden)  chargeTypeHidden.value  = conn.charge_type;
                }

                if (conn.product_type && productTypeSelect) {
                    const pt = productTypes.find(p => p.label === conn.product_type);
                    if (pt) {
                        productTypeSelect.value = pt.id;
                    }
                }
            }

            if (countrySelect) {
                countrySelect.addEventListener('change', function () {
                    rebuildNetworks();
                    rebuildMncs();
                });
            }

            if (networkSelect) {
                networkSelect.addEventListener('change', function () {
                    rebuildMncs();
                });
            }

            if (mncSelect) {
                mncSelect.addEventListener('change', function () {
                    applyNetworkMncDetails();
                });
            }

            if (supplierSelect) {
                supplierSelect.addEventListener('change', function () {
                    rebuildConnections();
                });
            }

            if (connectionSelect) {
                connectionSelect.addEventListener('change', function () {
                    applyConnectionDefaults();
                });
            }

            // Initial build
            rebuildNetworks();
            rebuildMncs();
            rebuildConnections();
        });
    </script>
</x-app-layout>
