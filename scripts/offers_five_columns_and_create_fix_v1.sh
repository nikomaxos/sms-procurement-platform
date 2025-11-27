#!/usr/bin/env bash
set -euo pipefail

echo "Running offers_five_columns_and_create_fix_v1.sh..."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F-%H%M%S)"
BACKUP_DIR=".backups/offers_five_columns_and_create_fix_v1_${STAMP}"
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
# 1) INDEX: force 5 columns for the filters via inline CSS grid
###############################################################################
if [ -f "$INDEX" ]; then
  echo "Patching filters grid in $INDEX to 5 columns..."
  perl -0pi -e 's/<div class="grid[^"]*gap-3">/<div class="grid gap-3" style="grid-template-columns: repeat(5, minmax(0, 1fr));">/1' "$INDEX"
fi

###############################################################################
# 2) CREATE: full rewrite, 5 fields per row, no Charge Model, no tricky @php
###############################################################################
echo "Rewriting $CREATE..."

cat > "$CREATE" << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ __('Create Offer') }}
        </h2>
    </x-slot>

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

                        <!-- 5 fields per row via explicit CSS grid -->
                        <div class="grid gap-4" style="grid-template-columns: repeat(5, minmax(0, 1fr));">
                            <!-- Country -->
                            <div>
                                <label for="country_id" class="block text-xs font-semibold text-gray-600 mb-1">
                                    {{ __('Country') }}
                                </label>
                                <select name="country_id"
                                        id="country_id"
                                        class="w-full rounded-md border-gray-300 text-xs sm:text-sm">
                                    <option value="">{{ __('Select country') }}</option>
                                    @foreach (($countries ?? []) as $country)
                                        <option value="{{ $country->id }}" {{ (string)old('country_id') === (string)$country->id ? 'selected' : '' }}>
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
                                    @foreach (($networks ?? []) as $network)
                                        <option value="{{ $network->id }}"
                                                data-country-id="{{ $network->country_id ?? '' }}"
                                                {{ (string)old('network_id') === (string)$network->id ? 'selected' : '' }}>
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
                                    @foreach (($networkMncs ?? []) as $nm)
                                        @php
                                            $mncPadded = sprintf('%02d', (int)$nm->mnc);
                                            $mccStr    = (string)$nm->mcc;
                                            $mccMncLbl = $mccStr . $mncPadded;
                                        @endphp
                                        <option value="{{ $nm->id }}"
                                                data-network-id="{{ $nm->network_id }}"
                                                data-mcc="{{ $mccStr }}"
                                                data-mnc="{{ $mncPadded }}"
                                                {{ (string)old('network_mnc_id') === (string)$nm->id ? 'selected' : '' }}>
                                            {{ $mccMncLbl }}
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
                                    @foreach (($suppliers ?? []) as $supplier)
                                        <option value="{{ $supplier->id }}" {{ (string)old('supplier_id') === (string)$supplier->id ? 'selected' : '' }}>
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
                                    @foreach (($connections ?? []) as $connection)
                                        <option value="{{ $connection->id }}"
                                                data-supplier-id="{{ $connection->supplier_id }}"
                                                data-product-type-label="{{ $connection->product_type }}"
                                                data-charge-type="{{ $connection->charge_type }}"
                                                {{ (string)old('supplier_connection_id') === (string)$connection->id ? 'selected' : '' }}>
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
                                    <option value="per_submit" {{ old('charge_type') === 'per_submit' ? 'selected' : '' }}>
                                        {{ __('Per Submit') }}
                                    </option>
                                    <option value="per_delivered" {{ old('charge_type') === 'per_delivered' ? 'selected' : '' }}>
                                        {{ __('Per Delivered') }}
                                    </option>
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
                                    @foreach (($productTypeItems ?? []) as $item)
                                        <option value="{{ $item->id }}" {{ (string)old('product_type_id') === (string)$item->id ? 'selected' : '' }}>
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
                                    @foreach (($knownHopsItems ?? []) as $item)
                                        <option value="{{ $item->id }}" {{ (string)old('known_hops_dropdown_item_id') === (string)$item->id ? 'selected' : '' }}>
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
                                    @foreach (($senderIdSupportedItems ?? []) as $item)
                                        <option value="{{ $item->id }}" {{ (string)old('sender_id_supported_dropdown_item_id') === (string)$item->id ? 'selected' : '' }}>
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
                                       {{ old('is_exclusive') ? 'checked' : '' }}>
                                <label for="is_exclusive" class="ml-2 text-xs font-semibold text-gray-600">
                                    {{ __('Exclusive offer') }}
                                </label>
                            </div>
                        </div>

                        <!-- Hidden MCC/MNC fields (populated from selected MNC option) -->
                        <input type="hidden" name="mcc" id="mcc" value="{{ old('mcc') }}">
                        <input type="hidden" name="mnc" id="mnc" value="{{ old('mnc') }}">

                        <!-- Notes -->
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
            const countrySelect    = document.getElementById('country_id');
            const networkSelect    = document.getElementById('network_id');
            const mncSelect        = document.getElementById('network_mnc_id');
            const supplierSelect   = document.getElementById('supplier_id');
            const connectionSelect = document.getElementById('supplier_connection_id');
            const productTypeSelect= document.getElementById('product_type_id');
            const chargeTypeSelect = document.getElementById('charge_type');
            const priceInput       = document.getElementById('price');
            const mccInput         = document.getElementById('mcc');
            const mncInput         = document.getElementById('mnc');
            const mccMncInput      = document.getElementById('mcc_mnc');
            const form             = document.getElementById('create-offer-form');

            let allNetworkOptions    = [];
            let allMncOptions        = [];
            let allConnectionOptions = [];

            if (networkSelect)   allNetworkOptions    = Array.from(networkSelect.options);
            if (mncSelect)       allMncOptions        = Array.from(mncSelect.options);
            if (connectionSelect)allConnectionOptions = Array.from(connectionSelect.options);

            // Build connection meta & product type mapping from JSON
            const connectionsData   = @json($connections ?? []);
            const productTypesData  = @json($productTypeItems ?? []);

            const productTypeLabelToId = {};
            productTypesData.forEach(function (pt) {
                if (pt && pt.label != null) {
                    productTypeLabelToId[String(pt.label)] = pt.id;
                }
            });

            const connectionMeta = {};
            connectionsData.forEach(function (c) {
                if (!c || c.id == null) return;
                const label = c.product_type || '';
                connectionMeta[String(c.id)] = {
                    supplier_id:         c.supplier_id || null,
                    product_type_label:  label,
                    product_type_id:     productTypeLabelToId[label] || null,
                    charge_type:         c.charge_type || ''
                };
            });

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

                if (meta.supplier_id && supplierSelect && !supplierSelect.value) {
                    supplierSelect.value = String(meta.supplier_id);
                }

                if (meta.product_type_id && productTypeSelect) {
                    productTypeSelect.value = String(meta.product_type_id);
                }

                if (meta.charge_type && chargeTypeSelect) {
                    chargeTypeSelect.value = meta.charge_type;
                }
            }

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

            // Initial state for old() values
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

echo "offers_five_columns_and_create_fix_v1.sh done."
