<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ ($offer ?? null) && $offer->exists ? 'Edit Offer' : 'Create Offer' }}
        </h2>
    </x-slot>

    @php
        $isEdit = ($offer ?? null) && $offer->exists;

        // Safe defaults in case controller δεν τα στείλει
        $selectedProductTypeId       = $selectedProductTypeId       ?? null;
        $selectedKnownHopsId         = $selectedKnownHopsId         ?? null;
        $selectedSenderIdSupportedId = $selectedSenderIdSupportedId ?? null;

        // Charge type options από offers (μικρό query)
        $chargeTypeOptions = \App\Models\SupplierOffer::query()
            ->select('charge_type')
            ->whereNotNull('charge_type')
            ->distinct()
            ->orderBy('charge_type')
            ->pluck('charge_type');

        // Network MNC labels per network για να δείχνουμε MCC/MNC δίπλα στο όνομα
        $networkMncs = $networkMncs ?? collect();
        if (!($networkMncs instanceof \Illuminate\Support\Collection)) {
            $networkMncs = collect($networkMncs);
        }
        $networkMncLabelsByNetwork = $networkMncs->groupBy('network_id')->map(function ($items) {
            return $items->pluck('mcc_mnc')->unique()->values();
        });
    @endphp

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
            <form
                method="POST"
                action="{{ $isEdit ? route('offers.update', $offer) : route('offers.store') }}"
                class="grid grid-cols-1 md:grid-cols-2 gap-4"
            >
                @csrf
                @if($isEdit)
                    @method('PUT')
                @endif

                {{-- Country (locked on edit) --}}
                <div>
                    <label for="country_id" class="block text-sm font-medium text-gray-700">Country</label>
                    @if(!$isEdit)
                        <select id="country_id" name="country_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                    @else
                        <select id="country_id" name="country_id_display"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm bg-gray-100 text-gray-700 cursor-not-allowed"
                                disabled>
                    @endif
                            <option value="">Select country</option>
                            @foreach($countries as $country)
                                <option value="{{ $country->id }}"
                                    @selected(old('country_id', $offer->country_id) == $country->id)>
                                    {{ $country->name }}
                                </option>
                            @endforeach
                        </select>
                    @if($isEdit)
                        <input type="hidden" name="country_id" value="{{ old('country_id', $offer->country_id) }}">
                    @endif
                </div>

                {{-- Network (locked on edit, αλλά label με MCC/MNC) --}}
                <div>
                    <label for="network_id" class="block text-sm font-medium text-gray-700">Network</label>
                    @if(!$isEdit)
                        <select id="network_id" name="network_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                    @else
                        <select id="network_id" name="network_id_display"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm bg-gray-100 text-gray-700 cursor-not-allowed"
                                disabled>
                    @endif
                            <option value="">Select network</option>
                            @foreach($networks as $network)
                                @php
                                    $mccMncList = $networkMncLabelsByNetwork[$network->id] ?? collect();
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
                    @if($isEdit)
                        <input type="hidden" name="network_id" value="{{ old('network_id', $offer->network_id) }}">
                    @endif
                    <p id="network_mccmnc_info" class="mt-1 text-xs text-gray-500 hidden"></p>
                </div>

                {{-- Supplier --}}
                <div>
                    <label for="supplier_id" class="block text-sm font-medium text-gray-700">Supplier</label>
                    <select id="supplier_id" name="supplier_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select supplier</option>
                        @foreach($suppliers as $supplier)
                            <option value="{{ $supplier->id }}"
                                @selected(old('supplier_id', $offer->supplier_id) == $supplier->id)>
                                {{ $supplier->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Connection (drives Product Type + Charge Type + Username) --}}
                <div>
                    <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">Connection</label>
                    <select id="supplier_connection_id" name="supplier_connection_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select connection</option>
                        @foreach($connections as $connection)
                            <option value="{{ $connection->id }}"
                                    data-username="{{ $connection->username ?? '' }}"
                                    data-charge-type="{{ $connection->charge_type ?? '' }}"
                                    data-product-type-id="{{ $connection->product_type_id ?? ($connection->product_type_dropdown_item_id ?? '') }}"
                                    data-product-type-label="{{ $connection->product_type ?? '' }}"
                                    @selected(old('supplier_connection_id', $offer->supplier_connection_id) == $connection->id)>
                                {{ $connection->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- MNC (can always change; loaded via JSON per network) --}}
                <div>
                    <label for="network_mnc_id" class="block text-sm font-medium text-gray-700">MNC</label>
                    <select id="network_mnc_id" name="network_mnc_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">
                            @if($isEdit && $offer->network_mnc_id)
                                Loading...
                            @else
                                Select network first
                            @endif
                        </option>
                    </select>
                    <p class="mt-1 text-xs text-gray-500">
                        A supplier offer refers to exactly one MNC.
                    </p>
                </div>

                {{-- Price (locked on edit) --}}
                <div>
                    <label for="price" class="block text-sm font-medium text-gray-700">Price</label>
                    <input id="price"
                           name="price"
                           type="text"
                           value="{{ old('price', $offer->price_trimmed ?? $offer->price) }}"
                           class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                           {{ $isEdit ? 'readonly' : '' }}
                           required>
                    <p class="mt-1 text-xs text-gray-500">
                        Stored trimmed (e.g. 0.03500 → 0.035).
                    </p>
                </div>

                {{-- Product Type (dropdown menu 1) --}}
                <div>
                    <label for="product_type_id" class="block text-sm font-medium text-gray-700">Product Type</label>
                    <select id="product_type_id" name="product_type_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($productTypeOptions as $item)
                            <option value="{{ $item->id }}"
                                @selected(old('product_type_id', $selectedProductTypeId) == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Charge Type (dropdown) --}}
                <div>
                    <label for="charge_type" class="block text-sm font-medium text-gray-700">Charge Type</label>
                    <select id="charge_type" name="charge_type"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($chargeTypeOptions as $ct)
                            <option value="{{ $ct }}"
                                @selected(old('charge_type', $offer->charge_type) == $ct)>
                                {{ ucwords(str_replace('_', ' ', $ct)) }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Known Hops (dropdown menu 2) --}}
                <div>
                    <label for="known_hops_dropdown_item_id" class="block text-sm font-medium text-gray-700">Known Hops</label>
                    <select id="known_hops_dropdown_item_id" name="known_hops_dropdown_item_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($knownHopsOptions as $item)
                            <option value="{{ $item->id }}"
                                @selected(old('known_hops_dropdown_item_id', $selectedKnownHopsId) == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Sender ID Supported (dropdown menu 3) --}}
                <div>
                    <label for="sender_id_supported_dropdown_item_id"
                           class="block text-sm font-medium text-gray-700">
                        Sender ID Supported
                    </label>
                    <select id="sender_id_supported_dropdown_item_id" name="sender_id_supported_dropdown_item_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($senderIdOptions as $item)
                            <option value="{{ $item->id }}"
                                @selected(old('sender_id_supported_dropdown_item_id', $selectedSenderIdSupportedId) == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Connection Username (always readonly, dynamic on connection change) --}}
                <div>
                    <label class="block text-sm font-medium text-gray-700">Connection Username</label>
                    <input id="connection_username"
                           type="text"
                           value="{{ optional($offer->connection)->username }}"
                           class="mt-1 block w-full border-gray-300 rounded-md shadow-sm bg-gray-100 text-gray-700"
                           readonly>
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
                <div class="mt-4 col-span-1 md:col-span-2 flex justify-between items-center gap-2">
                    <div>
                        <a href="{{ route('offers.index') }}"
                           class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm bg-white text-gray-700 hover:bg-gray-50">
                            Back to Offers
                        </a>
                    </div>
                    <div class="flex gap-2">
                        @if($isEdit)
                            {{-- Delete button only in edit --}}
                            <form method="POST" action="{{ route('offers.destroy', $offer) }}"
                                  onsubmit="return confirm('Are you sure you want to delete this offer?');">
                                @csrf
                                @method('DELETE')
                                <button type="submit"
                                        class="inline-flex items-center px-4 py-2 border border-red-600 text-sm font-medium rounded-md shadow-sm bg-white text-red-600 hover:bg-red-50">
                                    Delete
                                </button>
                            </form>
                        @endif
                        <button type="submit"
                                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                            {{ $isEdit ? 'Save Changes' : 'Create Offer' }}
                        </button>
                    </div>
                </div>
            </form>
        </div>
    </div>

    {{-- JS: filter networks by country, load MNCs via JSON, defaults from Connection (incl. username) --}}
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const countrySelect      = document.getElementById('country_id');
            const networkSelect      = document.getElementById('network_id');
            const mncSelect          = document.getElementById('network_mnc_id');
            const connectionSelect   = document.getElementById('supplier_connection_id');
            const productTypeSelect  = document.getElementById('product_type_id');
            const chargeTypeSelect   = document.getElementById('charge_type');
            const mccInfo            = document.getElementById('network_mccmnc_info');
            const connectionUsernameInput = document.getElementById('connection_username');

            const mncsEndpointBase   = "{{ url('/offers/network') }}";
            const connDefaultsBase   = "{{ url('/offers/connection') }}";
            const oldMncId           = "{{ old('network_mnc_id', $offer->network_mnc_id) }}";

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
                loadMncsForNetwork();
            }

            function loadMncsForNetwork() {
                if (!networkSelect || !mncSelect) return;
                const networkId = networkSelect.value;

                mncSelect.innerHTML = '';
                if (mccInfo) {
                    mccInfo.textContent = '';
                    mccInfo.classList.add('hidden');
                }

                if (!networkId) {
                    const opt = document.createElement('option');
                    opt.value = '';
                    opt.textContent = 'Select network first';
                    mncSelect.appendChild(opt);
                    return;
                }

                const loadingOpt = document.createElement('option');
                loadingOpt.value = '';
                loadingOpt.textContent = 'Loading...';
                mncSelect.appendChild(loadingOpt);

                fetch(`${mncsEndpointBase}/${networkId}/mncs-json`)
                    .then(resp => resp.json())
                    .then(data => {
                        const mncs = data.mncs || [];
                        mncSelect.innerHTML = '';

                        const placeholder = document.createElement('option');
                        placeholder.value = '';
                        placeholder.textContent = '(optional)';
                        mncSelect.appendChild(placeholder);

                        const labels = [];
                        mncs.forEach(m => {
                            const opt = document.createElement('option');
                            opt.value = m.id;
                            opt.textContent = m.mcc_mnc;
                            labels.push(m.mcc_mnc);
                            if (oldMncId && String(m.id) === String(oldMncId)) {
                                opt.selected = true;
                            }
                            mncSelect.appendChild(opt);
                        });

                        if (mccInfo) {
                            if (labels.length) {
                                mccInfo.textContent = 'MCC/MNC: ' + labels.join(', ');
                                mccInfo.classList.remove('hidden');
                            } else {
                                mccInfo.textContent = '';
                                mccInfo.classList.add('hidden');
                            }
                        }
                    })
                    .catch(() => {
                        mncSelect.innerHTML = '';
                        const opt = document.createElement('option');
                        opt.value = '';
                        opt.textContent = '(error loading MNCs)';
                        mncSelect.appendChild(opt);
                        if (mccInfo) {
                            mccInfo.textContent = '';
                            mccInfo.classList.add('hidden');
                        }
                    });
            }

            function applyConnectionDefaults() {
                if (!connectionSelect) return;
                const selected = connectionSelect.selectedOptions[0];
                if (!selected) return;

                const connectionId      = selected.value;
                const productTypeIdAttr = selected.getAttribute('data-product-type-id') || '';
                const productTypeLabel  = selected.getAttribute('data-product-type-label') || '';
                const chargeTypeAttr    = selected.getAttribute('data-charge-type') || '';
                const connUsername      = selected.getAttribute('data-username') || '';

                let productSet = false;

                // Product Type από data attributes (ID ή label)
                if (productTypeSelect) {
                    if (productTypeIdAttr) {
                        productTypeSelect.value = productTypeIdAttr;
                        if (productTypeSelect.value === productTypeIdAttr) {
                            productSet = true;
                        }
                    }

                    if (!productSet && productTypeLabel) {
                        const match = Array.from(productTypeSelect.options).find(o =>
                            o.text.trim().toLowerCase() === productTypeLabel.trim().toLowerCase()
                        );
                        if (match) {
                            productTypeSelect.value = match.value;
                            productSet = true;
                        }
                    }
                }

                // Charge Type από connection attribute
                if (chargeTypeSelect && chargeTypeAttr) {
                    const opt = Array.from(chargeTypeSelect.options).find(o => o.value === chargeTypeAttr);
                    if (opt) {
                        chargeTypeSelect.value = chargeTypeAttr;
                    }
                }

                // Connection username dynamic
                if (connectionUsernameInput) {
                    connectionUsernameInput.value = connUsername;
                }

                // Αν ακόμη δεν βρέθηκε Product Type, ρώτα τον server (τελευταία offer για το connection)
                if (!productSet && connectionId) {
                    fetch(`${connDefaultsBase}/${connectionId}/defaults-json`)
                        .then(resp => resp.json())
                        .then(data => {
                            if (!productTypeSelect) return;

                            let pid    = data.product_type_id || '';
                            let plabel = data.product_type_label || '';

                            if (pid) {
                                productTypeSelect.value = pid;
                            }

                            if (!productTypeSelect.value && plabel) {
                                const match = Array.from(productTypeSelect.options).find(o =>
                                    o.text.trim().toLowerCase() === plabel.trim().toLowerCase()
                                );
                                if (match) {
                                    productTypeSelect.value = match.value;
                                }
                            }

                            if (chargeTypeSelect && data.charge_type) {
                                const opt = Array.from(chargeTypeSelect.options).find(o => o.value === data.charge_type);
                                if (opt) {
                                    chargeTypeSelect.value = data.charge_type;
                                }
                            }

                            if (connectionUsernameInput && data.username) {
                                connectionUsernameInput.value = data.username;
                            }
                        })
                        .catch(() => {
                            // σιωπηλή αποτυχία
                        });
                }
            }

            if (countrySelect) {
                countrySelect.addEventListener('change', filterNetworksByCountry);
            }
            if (networkSelect) {
                networkSelect.addEventListener('change', loadMncsForNetwork);
            }
            if (connectionSelect) {
                connectionSelect.addEventListener('change', applyConnectionDefaults);
            }

            // Initial state
            filterNetworksByCountry();
            loadMncsForNetwork();
            applyConnectionDefaults();
        });
    </script>
</x-app-layout>
