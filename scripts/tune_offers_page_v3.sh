#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_v3_$(date +%F_%H-%M-%S)"

echo "==> Backup to: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/app/Models" \
         "${BACKUP_DIR}/app/Http/Controllers" \
         "${BACKUP_DIR}/resources/views/offers"

cp app/Models/SupplierOffer.php                          "${BACKUP_DIR}/app/Models/" 2>/dev/null || true
cp app/Http/Controllers/OffersController.php             "${BACKUP_DIR}/app/Http/Controllers/" 2>/dev/null || true
cp resources/views/offers/index.blade.php                "${BACKUP_DIR}/resources/views/offers/" 2>/dev/null || true
cp resources/views/offers/edit.blade.php                 "${BACKUP_DIR}/resources/views/offers/" 2>/dev/null || true

echo "==> Writing updated SupplierOffer model"
cat > app/Models/SupplierOffer.php << 'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SupplierOffer extends Model
{
    use HasFactory;

    protected $table = 'supplier_offers';

    protected $fillable = [
        'country_id',
        'network_id',
        'network_mnc_id',
        'supplier_id',
        'supplier_connection_id',
        'price',
        'mcc',
        'mnc',
        'mcc_mnc',
        'product_type',
        'product_type_id',
        'known_hops_dropdown_item_id',
        'sender_id_supported_dropdown_item_id',
        'route_type_id',
        'charge_model_id',
        'charge_type',
        'is_exclusive',
        'effective_date',
    ];

    protected $casts = [
        'is_exclusive'   => 'boolean',
        'effective_date' => 'date',
    ];

    public function country()
    {
        return $this->belongsTo(Country::class);
    }

    public function network()
    {
        return $this->belongsTo(Network::class);
    }

    public function networkMnc()
    {
        return $this->belongsTo(NetworkMnc::class, 'network_mnc_id');
    }

    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }

    public function connection()
    {
        return $this->belongsTo(SupplierConnection::class, 'supplier_connection_id');
    }

    public function productTypeDropdown()
    {
        return $this->belongsTo(DropdownItem::class, 'product_type_id');
    }

    public function knownHopsDropdown()
    {
        return $this->belongsTo(DropdownItem::class, 'known_hops_dropdown_item_id');
    }

    public function senderIdSupportedDropdown()
    {
        return $this->belongsTo(DropdownItem::class, 'sender_id_supported_dropdown_item_id');
    }

    public function getProductTypeLabelAttribute()
    {
        if ($this->productTypeDropdown) {
            return $this->productTypeDropdown->label;
        }

        return $this->product_type;
    }

    public function getKnownHopsLabelAttribute()
    {
        return optional($this->knownHopsDropdown)->label;
    }

    public function getSenderIdSupportedLabelAttribute()
    {
        return optional($this->senderIdSupportedDropdown)->label;
    }

    /**
     * Price χωρίς περιττά trailing zeros (0.03500 -> 0.035)
     */
    public function getPriceTrimmedAttribute()
    {
        if ($this->price === null) {
            return null;
        }

        $value = (string) $this->price;
        $value = rtrim(rtrim($value, '0'), '.');

        if ($value === '' || $value === '-0') {
            return '0';
        }

        return $value;
    }

    /**
     * Charge type human readable (per_submit -> Per Submit)
     */
    public function getChargeTypeLabelAttribute()
    {
        if ($this->charge_type === null || $this->charge_type === '') {
            return null;
        }

        $label = str_replace('_', ' ', $this->charge_type);

        if (function_exists('mb_convert_case')) {
            return mb_convert_case($label, MB_CASE_TITLE, 'UTF-8');
        }

        return ucwords($label);
    }
}
PHP

echo "==> Keeping OffersController from v2 (no changes here)"

# Δεν ξαναγράφω τον OffersController, κρατάω τον προηγούμενο v2 όπως είναι.
# Αν για κάποιο λόγο λείπει, θα ήταν ασφαλέστερο να σταματήσουμε εδώ:
if [ ! -f app/Http/Controllers/OffersController.php ]; then
  echo "ERROR: OffersController.php not found. Rollback from backup if needed."
  exit 1
fi

echo "==> Writing updated offers/index.blade.php"
cat > resources/views/offers/index.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offers
        </h2>
    </x-slot>

    <div class="py-6 max-w-7xl mx-auto sm:px-6 lg:px-8">
        <div class="bg-white p-4 rounded-lg shadow mb-4">
            <form method="GET" action="{{ route('offers.index') }}" class="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-4 items-end">
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

                <div class="flex gap-2">
                    <button type="submit" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                        Filter
                    </button>
                    <a href="{{ route('offers.index') }}" class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm bg-white text-gray-700 hover:bg-gray-50">
                        Clear
                    </a>
                </div>
            </form>
        </div>

        <div class="bg-white rounded-lg shadow overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">Country</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">Network</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">MCC/MNC</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">Supplier</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">Connection</th>
                        <th class="px-3 py-2 text-right font-medium text-gray-500 uppercase tracking-wider">Price</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">Product Type</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">Known Hops</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">Sender ID Supported</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">Charge Type</th>
                        <th class="px-3 py-2"></th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                    @forelse($offers as $offer)
                        <tr>
                            <td class="px-3 py-2">
                                {{ optional($offer->country)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2">
                                {{ optional($offer->network)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2">
                                @if($offer->mcc_mnc)
                                    {{ $offer->mcc_mnc }}
                                @elseif($offer->networkMnc)
                                    {{ $offer->networkMnc->mcc_mnc }}
                                @else
                                    -
                                @endif
                            </td>
                            <td class="px-3 py-2">
                                {{ optional($offer->supplier)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2">
                                {{ optional($offer->connection)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2 text-right">
                                {{ $offer->price_trimmed ?? '-' }}
                            </td>
                            <td class="px-3 py-2">
                                {{ $offer->product_type_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2">
                                {{ $offer->known_hops_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2">
                                {{ $offer->sender_id_supported_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2">
                                {{ $offer->charge_type_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2 text-right">
                                <a href="{{ route('offers.edit', $offer) }}" class="text-blue-600 hover:text-blue-900 text-sm">
                                    Edit
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="11" class="px-3 py-4 text-center text-gray-500">
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

echo "==> Writing updated offers/edit.blade.php"
cat > resources/views/offers/edit.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Edit Offer #{{ $offer->id }}
        </h2>
    </x-slot>

    <div class="py-6 max-w-4xl mx-auto sm:px-6 lg:px-8">
        <div class="bg-white overflow-hidden shadow-sm rounded-lg">
            <div class="p-6">
                @if ($errors->any())
                    <div class="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
                        <div class="font-semibold mb-1">There were some problems with your input:</div>
                        <ul class="list-disc pl-5 text-sm">
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

                <form method="POST" action="{{ route('offers.update', $offer) }}">
                    @csrf
                    @method('PUT')

                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        {{-- Country --}}
                        <div>
                            <label for="country_id" class="block text-sm font-medium text-gray-700">Country</label>
                            <select id="country_id" name="country_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                @foreach($countries as $country)
                                    <option value="{{ $country->id }}" @selected(old('country_id', $offer->country_id) == $country->id)>
                                        {{ $country->name }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Network (με MCC/MNC σύνοψη, φιλτραρισμένο ανά χώρα μέσω JS) --}}
                        <div>
                            <label for="network_id" class="block text-sm font-medium text-gray-700">Network</label>
                            <select id="network_id" name="network_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                @foreach($networks as $network)
                                    @php
                                        $summary = $networkMncSummary[$network->id] ?? null;
                                    @endphp
                                    <option value="{{ $network->id }}"
                                            data-country-id="{{ $network->country_id ?? '' }}"
                                            @selected(old('network_id', $offer->network_id) == $network->id)>
                                        {{ $network->name }}@if($summary)  {{ $summary }}@endif
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Supplier --}}
                        <div>
                            <label for="supplier_id" class="block text-sm font-medium text-gray-700">Supplier</label>
                            <select id="supplier_id" name="supplier_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                @foreach($suppliers as $supplier)
                                    <option value="{{ $supplier->id }}" @selected(old('supplier_id', $offer->supplier_id) == $supplier->id)>
                                        {{ $supplier->name }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Connection (φέρνει defaults για charge_type & product_type) --}}
                        <div>
                            <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">Connection</label>
                            <select id="supplier_connection_id" name="supplier_connection_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">—</option>
                                @foreach($connections as $connection)
                                    <option value="{{ $connection->id }}"
                                        data-charge-type="{{ $connection->charge_type ?? '' }}"
                                        data-product-type-label="{{ $connection->product_type ?? '' }}"
                                        @selected(old('supplier_connection_id', $offer->supplier_connection_id) == $connection->id)>
                                        {{ $connection->name }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- MNC (φιλτραρισμένο από το Network) --}}
                        <div>
                            <label for="network_mnc_id" class="block text-sm font-medium text-gray-700">MNC</label>
                            <select id="network_mnc_id" name="network_mnc_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">—</option>
                                @foreach($networkMncs as $nm)
                                    @php
                                        $mncRaw = (string) $nm->mnc;
                                        $len = strlen($mncRaw);
                                        $padLen = $len < 2 ? 2 : $len;
                                        $mncDisplay = str_pad($mncRaw, $padLen, '0', STR_PAD_LEFT);
                                    @endphp
                                    <option value="{{ $nm->id }}"
                                        data-network-id="{{ $nm->network_id }}"
                                        @selected(old('network_mnc_id', $offer->network_mnc_id) == $nm->id)>
                                        {{ $mncDisplay }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Price --}}
                        <div>
                            <label for="price" class="block text-sm font-medium text-gray-700">Price</label>
                            <input type="number" step="0.0000001" min="0" name="price" id="price"
                                   value="{{ old('price', $offer->price_trimmed ?? $offer->price) }}"
                                   class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        </div>

                        {{-- Product Type dropdown (menu_id=1) --}}
                        <div>
                            <label for="product_type_id" class="block text-sm font-medium text-gray-700">Product Type</label>
                            <select id="product_type_id" name="product_type_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">—</option>
                                @foreach($productTypeOptions as $item)
                                    <option value="{{ $item->id }}"
                                        @selected(old('product_type_id', $selectedProductTypeId) == $item->id)>
                                        {{ $item->label }}
                                    </option>
                                @endforeach
                            </select>
                            <p class="mt-1 text-xs text-gray-500">
                                The legacy <code>product_type</code> string will be kept in sync with this dropdown.
                            </p>
                        </div>

                        {{-- Known Hops dropdown (menu_id=2) --}}
                        <div>
                            <label for="known_hops_dropdown_item_id" class="block text-sm font-medium text-gray-700">Known Hops</label>
                            <select id="known_hops_dropdown_item_id" name="known_hops_dropdown_item_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">—</option>
                                @foreach($knownHopsOptions as $item)
                                    <option value="{{ $item->id }}"
                                        @selected(old('known_hops_dropdown_item_id', $selectedKnownHopsId) == $item->id)>
                                        {{ $item->label }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Sender ID Supported dropdown (menu_id=3) --}}
                        <div>
                            <label for="sender_id_supported_dropdown_item_id" class="block text-sm font-medium text-gray-700">Sender ID Supported</label>
                            <select id="sender_id_supported_dropdown_item_id" name="sender_id_supported_dropdown_item_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">—</option>
                                @foreach($senderIdOptions as $item)
                                    <option value="{{ $item->id }}"
                                        @selected(old('sender_id_supported_dropdown_item_id', $selectedSenderIdSupportedId) == $item->id)>
                                        {{ $item->label }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Charge Type (dropdown, human readable labels) --}}
                        <div>
                            <label for="charge_type" class="block text-sm font-medium text-gray-700">Charge Type</label>
                            <select id="charge_type" name="charge_type" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">—</option>
                                @foreach($chargeTypeOptions as $ct)
                                    <option value="{{ $ct }}" @selected(old('charge_type', $offer->charge_type) == $ct)>
                                        {{ ucwords(str_replace('_', ' ', $ct)) }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Exclusive --}}
                        <div class="flex items-center mt-6">
                            <input id="is_exclusive" name="is_exclusive" type="checkbox" value="1" class="h-4 w-4 text-blue-600 border-gray-300 rounded"
                                   @checked(old('is_exclusive', $offer->is_exclusive))>
                            <label for="is_exclusive" class="ml-2 block text-sm text-gray-700">
                                Exclusive
                            </label>
                        </div>

                        {{-- Effective date --}}
                        <div>
                            <label for="effective_date" class="block text-sm font-medium text-gray-700">Effective Date</label>
                            <input type="date" name="effective_date" id="effective_date"
                                   value="{{ old('effective_date', optional($offer->effective_date)->format('Y-m-d')) }}"
                                   class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        </div>
                    </div>

                    <div class="mt-6 flex justify-between">
                        <a href="{{ route('offers.index') }}" class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50">
                            Cancel
                        </a>
                        <button type="submit" class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700">
                            Save
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    {{-- Vanilla JS για:
         - Dynamic Charge Type & Product Type από Connection
         - MNC filtering by Network
         - Network filtering by Country --}}
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const countrySelect      = document.getElementById('country_id');
            const networkSelect      = document.getElementById('network_id');
            const connectionSelect   = document.getElementById('supplier_connection_id');
            const chargeTypeSelect   = document.getElementById('charge_type');
            const productTypeSelect  = document.getElementById('product_type_id');
            const mncSelect          = document.getElementById('network_mnc_id');

            function filterMncOptions() {
                if (!networkSelect || !mncSelect) return;
                const networkId = networkSelect.value;

                let firstMatching = null;
                Array.from(mncSelect.options).forEach(opt => {
                    if (!opt.value) {
                        opt.hidden = false;
                        return;
                    }
                    const optNetworkId = opt.getAttribute('data-network-id');
                    if (optNetworkId === networkId) {
                        opt.hidden = false;
                        if (!firstMatching) {
                            firstMatching = opt;
                        }
                    } else {
                        opt.hidden = true;
                    }
                });

                const selectedOpt = mncSelect.selectedOptions[0];
                if (selectedOpt && selectedOpt.hidden && firstMatching) {
                    mncSelect.value = firstMatching.value;
                }
            }

            function filterNetworkOptions() {
                if (!countrySelect || !networkSelect) return;
                const countryId = countrySelect.value;

                let firstVisibleForCountry = null;

                Array.from(networkSelect.options).forEach(opt => {
                    if (!opt.value) {
                        opt.hidden = false;
                        return;
                    }
                    const optCountryId = opt.getAttribute('data-country-id');
                    // Αν δεν έχει επιλεγεί χώρα, δείξε όλα
                    if (!countryId || !optCountryId || optCountryId === countryId) {
                        opt.hidden = false;
                        if (optCountryId === countryId && !firstVisibleForCountry) {
                            firstVisibleForCountry = opt;
                        }
                    } else {
                        opt.hidden = true;
                    }
                });

                const selectedOpt = networkSelect.selectedOptions[0];
                if (selectedOpt && selectedOpt.hidden && firstVisibleForCountry) {
                    networkSelect.value = firstVisibleForCountry.value;
                    filterMncOptions();
                }
            }

            function applyConnectionDefaults() {
                if (!connectionSelect) return;
                const opt = connectionSelect.selectedOptions[0];
                if (!opt) return;

                const chargeType       = opt.getAttribute('data-charge-type');
                const productTypeLabel = opt.getAttribute('data-product-type-label');

                if (chargeTypeSelect && chargeType) {
                    const exists = Array.from(chargeTypeSelect.options).some(o => o.value === chargeType);
                    if (exists) {
                        chargeTypeSelect.value = chargeType;
                    }
                }

                if (productTypeSelect && productTypeLabel) {
                    const options = Array.from(productTypeSelect.options);
                    const match = options.find(o => o.textContent.trim() === productTypeLabel.trim());
                    if (match) {
                        productTypeSelect.value = match.value;
                    }
                }
            }

            if (connectionSelect) {
                connectionSelect.addEventListener('change', applyConnectionDefaults);
                applyConnectionDefaults();
            }

            if (networkSelect && mncSelect) {
                networkSelect.addEventListener('change', filterMncOptions);
                filterMncOptions();
            }

            if (countrySelect && networkSelect) {
                countrySelect.addEventListener('change', filterNetworkOptions);
                filterNetworkOptions();
            }
        });
    </script>
</x-app-layout>
BLADE

echo "==> Done. Backup in: ${BACKUP_DIR}"
echo "If needed, rollback by copying files back from backup."
