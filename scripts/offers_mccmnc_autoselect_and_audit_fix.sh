#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_mccmnc_autoselect_and_audit_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p \
  "${BACKUP_DIR}/app/Http/Controllers" \
  "${BACKUP_DIR}/resources/views/offers"

cp app/Http/Controllers/OffersController.php "${BACKUP_DIR}/app/Http/Controllers/" || true
cp resources/views/offers/index.blade.php "${BACKUP_DIR}/resources/views/offers/" || true
cp resources/views/offers/edit.blade.php "${BACKUP_DIR}/resources/views/offers/" || true

########################################
# Rewrite OffersController.php
########################################
cat > app/Http/Controllers/OffersController.php << 'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\SupplierOffer;
use App\Models\Country;
use App\Models\Network;
use App\Models\NetworkMnc;
use App\Models\Supplier;
use App\Models\SupplierConnection;
use App\Models\DropdownItem;
use Illuminate\Http\Request;

class OffersController extends Controller
{
    public function index(Request $request)
    {
        $query = SupplierOffer::query()
            ->with([
                'country',
                'network',
                'networkMnc',
                'supplier',
                'connection',
                'productTypeDropdown',
                'knownHopsDropdown',
                'senderIdSupportedDropdown',
                'updater',
            ]);

        if ($request->filled('country_id')) {
            $query->where('country_id', $request->input('country_id'));
        }

        if ($request->filled('network_id')) {
            $query->where('network_id', $request->input('network_id'));
        }

        if ($request->filled('supplier_id')) {
            $query->where('supplier_id', $request->input('supplier_id'));
        }

        if ($request->filled('supplier_connection_id')) {
            $query->where('supplier_connection_id', $request->input('supplier_connection_id'));
        }

        if ($request->filled('product_type')) {
            $query->where('product_type', $request->input('product_type'));
        }

        if ($request->filled('known_hops_dropdown_item_id')) {
            $query->where('known_hops_dropdown_item_id', $request->input('known_hops_dropdown_item_id'));
        }

        if ($request->filled('sender_id_supported_dropdown_item_id')) {
            $query->where('sender_id_supported_dropdown_item_id', $request->input('sender_id_supported_dropdown_item_id'));
        }

        if ($request->filled('charge_type')) {
            $query->where('charge_type', $request->input('charge_type'));
        }

        $offers = $query
            ->orderBy('country_id')
            ->orderBy('network_id')
            ->orderBy('supplier_id')
            ->orderBy('price')
            ->paginate(50)
            ->appends($request->query());

        $countries   = Country::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();

        $productTypeFilterOptions = SupplierOffer::query()
            ->select('product_type')
            ->whereNotNull('product_type')
            ->distinct()
            ->orderBy('product_type')
            ->pluck('product_type');

        $knownHopsFilterOptions = DropdownItem::where('dropdown_menu_id', 2)
            ->orderBy('label')
            ->get();

        $senderIdFilterOptions = DropdownItem::where('dropdown_menu_id', 3)
            ->orderBy('label')
            ->get();

        $chargeTypeFilterOptions = SupplierOffer::query()
            ->select('charge_type')
            ->whereNotNull('charge_type')
            ->distinct()
            ->orderBy('charge_type')
            ->pluck('charge_type');

        return view('offers.index', [
            'offers'                   => $offers,
            'countries'                => $countries,
            'networks'                 => $networks,
            'suppliers'                => $suppliers,
            'connections'              => $connections,
            'productTypeFilterOptions' => $productTypeFilterOptions,
            'knownHopsFilterOptions'   => $knownHopsFilterOptions,
            'senderIdFilterOptions'    => $senderIdFilterOptions,
            'chargeTypeFilterOptions'  => $chargeTypeFilterOptions,
        ]);
    }

    public function edit(SupplierOffer $offer)
    {
        $countries   = Country::orderBy('name')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();
        $networkMncs = NetworkMnc::orderBy('mcc_mnc')->get();

        $productTypeOptions = DropdownItem::where('dropdown_menu_id', 1)->orderBy('label')->get();
        $knownHopsOptions   = DropdownItem::where('dropdown_menu_id', 2)->orderBy('label')->get();
        $senderIdOptions    = DropdownItem::where('dropdown_menu_id', 3)->orderBy('label')->get();

        $chargeTypeOptions = SupplierConnection::query()
            ->select('charge_type')
            ->whereNotNull('charge_type')
            ->distinct()
            ->orderBy('charge_type')
            ->pluck('charge_type');

        $networkMncSummary = NetworkMnc::select('network_id', 'mcc', 'mnc')
            ->orderBy('network_id')
            ->orderBy('mnc')
            ->get()
            ->groupBy('network_id')
            ->map(function ($rows) {
                $mcc = $rows->first()->mcc;
                $mncs = $rows->pluck('mnc')->unique()->implode(' - ');
                return "{$mcc} / {$mncs}";
            });

        $selectedProductTypeId = null;
        if (!empty($offer->product_type_id)) {
            $selectedProductTypeId = $offer->product_type_id;
        } elseif (!empty($offer->product_type)) {
            $matching = $productTypeOptions->firstWhere('label', $offer->product_type);
            if ($matching) {
                $selectedProductTypeId = $matching->id;
            }
        }

        $selectedKnownHopsId         = $offer->known_hops_dropdown_item_id;
        $selectedSenderIdSupportedId = $offer->sender_id_supported_dropdown_item_id;

        return view('offers.edit', [
            'offer'                       => $offer,
            'countries'                   => $countries,
            'suppliers'                   => $suppliers,
            'networks'                    => $networks,
            'connections'                 => $connections,
            'networkMncs'                 => $networkMncs,
            'networkMncSummary'           => $networkMncSummary,
            'productTypeOptions'          => $productTypeOptions,
            'knownHopsOptions'            => $knownHopsOptions,
            'senderIdOptions'             => $senderIdOptions,
            'chargeTypeOptions'           => $chargeTypeOptions,
            'selectedProductTypeId'       => $selectedProductTypeId,
            'selectedKnownHopsId'         => $selectedKnownHopsId,
            'selectedSenderIdSupportedId' => $selectedSenderIdSupportedId,
        ]);
    }

    public function update(Request $request, SupplierOffer $offer)
    {
        $this->ensureNetworkMncForRequest($request);

        $validated = $request->validate([
            'country_id'                          => ['required', 'integer', 'exists:countries,id'],
            'network_id'                          => ['required', 'integer', 'exists:networks,id'],
            'network_mnc_id'                      => ['nullable', 'integer', 'exists:network_mncs,id'],
            'supplier_id'                         => ['required', 'integer', 'exists:suppliers,id'],
            'supplier_connection_id'              => ['nullable', 'integer', 'exists:supplier_connections,id'],
            'price'                               => ['required', 'numeric', 'min:0'],
            'mcc'                                 => ['nullable', 'string', 'max:4'],
            'mnc'                                 => ['nullable', 'string', 'max:4'],
            'mcc_mnc'                             => ['nullable', 'string', 'max:8'],
            'product_type_id'                     => ['nullable', 'integer', 'exists:dropdown_items,id'],
            'known_hops_dropdown_item_id'         => ['nullable', 'integer', 'exists:dropdown_items,id'],
            'sender_id_supported_dropdown_item_id'=> ['nullable', 'integer', 'exists:dropdown_items,id'],
            'route_type_id'                       => ['nullable', 'integer'],
            'charge_model_id'                     => ['nullable', 'integer'],
            'charge_type'                         => ['nullable', 'string', 'max:50'],
            'is_exclusive'                        => ['nullable', 'boolean'],
            'effective_date'                      => ['nullable', 'date'],
        ]);

        $validated['is_exclusive'] = $request->boolean('is_exclusive');

        if (isset($validated['price'])) {
            $validated['price'] = $this->normalizePrice($validated['price']);
        }

        $productTypeId = $validated['product_type_id'] ?? null;
        if ($productTypeId) {
            $dropdown = DropdownItem::find($productTypeId);
            $validated['product_type'] = $dropdown ? $dropdown->label : null;
        } else {
            $validated['product_type'] = null;
        }

        // ποιος έκανε το τελευταίο edit
        $validated['updated_by'] = optional($request->user())->id;

        $offer->update($validated);

        return redirect()
            ->route('offers.index')
            ->with('status', 'Offer updated successfully.');
    }

    private function normalizePrice($value): string
    {
        $str = (string) $value;
        $str = rtrim(rtrim($str, '0'), '.');

        if ($str === '' || $str === '-0') {
            return '0';
        }

        return $str;
    }

    public function create()
    {
        $offer = new SupplierOffer();

        $countries   = Country::orderBy('name')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();
        $networkMncs = NetworkMnc::orderBy('mcc_mnc')->get();

        $productTypeOptions = DropdownItem::where('dropdown_menu_id', 1)->orderBy('label')->get();
        $knownHopsOptions   = DropdownItem::where('dropdown_menu_id', 2)->orderBy('label')->get();
        $senderIdOptions    = DropdownItem::where('dropdown_menu_id', 3)->orderBy('label')->get();

        $selectedProductTypeId       = null;
        $selectedKnownHopsId         = null;
        $selectedSenderIdSupportedId = null;

        return view('offers.edit', compact(
            'offer',
            'countries',
            'suppliers',
            'networks',
            'connections',
            'networkMncs',
            'productTypeOptions',
            'knownHopsOptions',
            'senderIdOptions',
            'selectedProductTypeId',
            'selectedKnownHopsId',
            'selectedSenderIdSupportedId'
        ));
    }

    public function store(Request $request)
    {
        $this->ensureNetworkMncForRequest($request);

        $validated = $request->validate([
            'country_id'                          => ['required', 'integer'],
            'network_id'                          => ['required', 'integer'],
            'network_mnc_id'                      => ['nullable', 'integer'],
            'supplier_id'                         => ['required', 'integer'],
            'supplier_connection_id'              => ['required', 'integer'],
            'price'                               => ['required'],
            'product_type_id'                     => ['nullable', 'integer'],
            'known_hops_dropdown_item_id'         => ['nullable', 'integer'],
            'sender_id_supported_dropdown_item_id'=> ['nullable', 'integer'],
            'route_type_id'                       => ['nullable', 'integer'],
            'charge_model_id'                     => ['nullable', 'integer'],
            'charge_type'                         => ['nullable', 'string', 'max:255'],
            'is_exclusive'                        => ['nullable', 'boolean'],
            'effective_date'                      => ['nullable', 'date'],
        ]);

        if (isset($validated['price'])) {
            $priceStr = (string) $validated['price'];
            if (strpos($priceStr, '.') !== false) {
                $priceStr = rtrim($priceStr, '0');
                $priceStr = rtrim($priceStr, '.');
            }
            $validated['price'] = $priceStr;
        }

        $offer = new SupplierOffer();

        foreach ($validated as $key => $value) {
            $offer->{$key} = $value;
        }

        if (!empty($validated['product_type_id'])) {
            $item = DropdownItem::find($validated['product_type_id']);
            if ($item) {
                $offer->product_type = $item->label;
            }
        }

        // ποιος το δημιούργησε (για το Edited By)
        $offer->updated_by = optional($request->user())->id;

        $offer->save();

        return redirect()
            ->route('offers.edit', $offer)
            ->with('status', 'Offer created successfully.');
    }

    public function networkMncsJson($network)
    {
        $mncs = NetworkMnc::query()
            ->where('network_id', $network)
            ->orderBy('mcc_mnc')
            ->get(['id', 'mcc_mnc']);

        return response()->json([
            'mncs' => $mncs,
        ]);
    }

    public function connectionDefaultsJson($connection)
    {
        $defaults = [
            'product_type_id'    => null,
            'product_type_label' => null,
            'charge_type'        => null,
            'username'           => null,
        ];

        $conn = SupplierConnection::find($connection);
        if ($conn) {
            if (!empty($conn->charge_type)) {
                $defaults['charge_type'] = $conn->charge_type;
            }

            if (!empty($conn->product_type_id)) {
                $defaults['product_type_id'] = $conn->product_type_id;
            }
            if (empty($defaults['product_type_id']) && !empty($conn->product_type_dropdown_item_id)) {
                $defaults['product_type_id'] = $conn->product_type_dropdown_item_id;
            }

            if (!empty($conn->product_type)) {
                $defaults['product_type_label'] = $conn->product_type;
            }

            if (!empty($conn->username)) {
                $defaults['username'] = $conn->username;
            }
        }

        if (empty($defaults['product_type_id']) && empty($defaults['product_type_label'])) {
            $offer = SupplierOffer::query()
                ->where('supplier_connection_id', $connection)
                ->orderByDesc('updated_at')
                ->first();

            if ($offer) {
                if (!empty($offer->product_type_id)) {
                    $defaults['product_type_id'] = $offer->product_type_id;
                }
                if (!empty($offer->product_type)) {
                    $defaults['product_type_label'] = $offer->product_type;
                }
                if (empty($defaults['charge_type']) && !empty($offer->charge_type)) {
                    $defaults['charge_type'] = $offer->charge_type;
                }
            }
        }

        return response()->json($defaults);
    }

    public function destroy(SupplierOffer $offer)
    {
        $offer->delete();

        return redirect()
            ->route('offers.index')
            ->with('status', 'Offer deleted successfully.');
    }

    protected function ensureNetworkMncForRequest(Request $request): void
    {
        if (!$request->filled('network_id')) {
            return;
        }

        if ($request->filled('network_mnc_id')) {
            return;
        }

        $mncIds = NetworkMnc::where('network_id', $request->input('network_id'))
            ->pluck('id');

        if ($mncIds->count() === 1) {
            $request->merge([
                'network_mnc_id' => $mncIds->first(),
            ]);
        }
    }
}
PHP

########################################
# Rewrite resources/views/offers/index.blade.php
########################################
cat > resources/views/offers/index.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between">
            <h2 class="font-semibold text-xl text-gray-800 leading-tight">
                Offers
            </h2>

            <a href="{{ route('offers.create') }}"
               class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm bg-white text-gray-800 hover:bg-gray-50">
                Create Offer
            </a>
        </div>
    </x-slot>

    @php
        $trimPrice = function ($value) {
            if ($value === null || $value === '') {
                return null;
            }
            $str = (string) $value;
            $str = rtrim(rtrim($str, '0'), '.');
            return $str === '' ? '0' : $str;
        };

        $countryData = $countries->map(function ($country) {
            return [
                'id'    => $country->id,
                'label' => $country->name,
            ];
        })->values();

        $networkMccMncs = \App\Models\NetworkMnc::query()
            ->select('network_id', 'mcc_mnc')
            ->orderBy('mcc_mnc')
            ->get()
            ->groupBy('network_id');
    @endphp

    <div class="py-6 w-full max-w-full px-2 sm:px-4 lg:px-6 mx-auto">
        {{-- Filters --}}
        <div class="bg-white p-4 rounded-lg shadow mb-4">
            <form method="GET" action="{{ route('offers.index') }}" class="space-y-4">
                <div class="space-y-4">
                    <div class="flex -mx-2 flex-wrap">
                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_country_name" class="block text-sm font-medium text-gray-700">
                                Country
                            </label>
                            <input
                                id="filter_country_name"
                                type="text"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                                list="country_filter_options"
                                autocomplete="off"
                                placeholder="Search country..."
                            >
                            <datalist id="country_filter_options">
                                @foreach($countryData as $c)
                                    <option value="{{ $c['label'] }}"></option>
                                @endforeach
                            </datalist>
                            <input
                                type="hidden"
                                id="filter_country_id"
                                name="country_id"
                                value="{{ request('country_id') }}"
                            >
                        </div>

                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_network_id" class="block text-sm font-medium text-gray-700">
                                Network
                            </label>
                            <select
                                id="filter_network_id"
                                name="network_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                            >
                                <option value="">All</option>
                                @foreach($networks as $network)
                                    @php
                                        $label = $network->name;
                                        $mccCollection = $networkMccMncs->get($network->id);
                                        $mccList = $mccCollection
                                            ? $mccCollection->pluck('mcc_mnc')->filter()->unique()->values()->all()
                                            : [];
                                        if (!empty($mccList)) {
                                            $label .= ' — ' . implode(', ', $mccList);
                                        }
                                    @endphp
                                    <option value="{{ $network->id }}"
                                            data-country-id="{{ $network->country_id ?? '' }}"
                                            @selected((string)request('network_id') === (string)$network->id)>
                                        {{ $label }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        <div class="flex-1 px-2 min-w-[10rem]">
                            <label for="filter_mcc_mnc" class="block text-sm font-medium text-gray-700">
                                MCC/MNC
                            </label>
                            <input
                                id="filter_mcc_mnc"
                                name="mcc_mnc"
                                type="text"
                                value="{{ request('mcc_mnc') }}"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                                placeholder="e.g. 20201"
                                autocomplete="off"
                            >
                        </div>

                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_supplier_id" class="block text-sm font-medium text-gray-700">
                                Supplier
                            </label>
                            <select
                                id="filter_supplier_id"
                                name="supplier_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                            >
                                <option value="">All</option>
                                @foreach($suppliers as $supplier)
                                    <option value="{{ $supplier->id }}"
                                            @selected((string)request('supplier_id') === (string)$supplier->id)>
                                        {{ $supplier->name }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_connection_id" class="block text-sm font-medium text-gray-700">
                                Connection
                            </label>
                            <select
                                id="filter_connection_id"
                                name="supplier_connection_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                            >
                                <option value="">All</option>
                                @foreach($connections as $connection)
                                    <option value="{{ $connection->id }}"
                                            @selected((string)request('supplier_connection_id') === (string)$connection->id)>
                                        {{ $connection->name }}
                                    </option>
                                @endforeach
                            </select>
                        </div>
                    </div>

                    <div class="flex -mx-2 flex-wrap">
                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_product_type" class="block text-sm font-medium text-gray-700">
                                Product Type
                            </label>
                            <select
                                id="filter_product_type"
                                name="product_type"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                            >
                                <option value="">All</option>
                                @foreach($productTypeFilterOptions as $pt)
                                    <option value="{{ $pt }}"
                                            @selected(request('product_type') === $pt)>
                                        {{ $pt }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_known_hops" class="block text-sm font-medium text-gray-700">
                                Known Hops
                            </label>
                            <select
                                id="filter_known_hops"
                                name="known_hops_dropdown_item_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                            >
                                <option value="">All</option>
                                @foreach($knownHopsFilterOptions as $item)
                                    <option value="{{ $item->id }}"
                                            @selected((string)request('known_hops_dropdown_item_id') === (string)$item->id)>
                                        {{ $item->label }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_sender_id_supported" class="block text-sm font-medium text-gray-700">
                                Sender ID Supported
                            </label>
                            <select
                                id="filter_sender_id_supported"
                                name="sender_id_supported_dropdown_item_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                            >
                                <option value="">All</option>
                                @foreach($senderIdFilterOptions as $item)
                                    <option value="{{ $item->id }}"
                                            @selected((string)request('sender_id_supported_dropdown_item_id') === (string)$item->id)>
                                        {{ $item->label }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_charge_type" class="block text-sm font-medium text-gray-700">
                                Charge Type
                            </label>
                            <select
                                id="filter_charge_type"
                                name="charge_type"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                            >
                                <option value="">All</option>
                                @foreach($chargeTypeFilterOptions as $ct)
                                    <option value="{{ $ct }}"
                                            @selected(request('charge_type') === $ct)>
                                        {{ ucwords(str_replace('_', ' ', $ct)) }}
                                    </option>
                                @endforeach
                            </select>
                        </div>
                    </div>
                </div>

                <div class="flex justify-end gap-2 pt-4">
                    <a href="{{ route('offers.index') }}"
                       class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm rounded-md bg-white text-gray-700 hover:bg-gray-50">
                        Clear
                    </a>
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent text-sm rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                        Apply Filters
                    </button>
                </div>
            </form>
        </div>

        <div class="bg-white p-4 rounded-lg shadow">
            <div class="overflow-x-auto">
                <table class="min-w-full text-sm">
                    <thead>
                        <tr class="border-b bg-gray-50">
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Country</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Network</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">MCC/MNC</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Supplier</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Connection</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Conn. Username</th>
                            <th class="px-3 py-2 text-right font-semibold text-gray-700 whitespace-nowrap">Price</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Product Type</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Known Hops</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Sender ID Supported</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Charge Type</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Effective Date</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Last Edited</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Edited By</th>
                            <th class="px-3 py-2 text-right font-semibold text-gray-700 whitespace-nowrap">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($offers as $offer)
                            <tr class="border-b last:border-0 hover:bg-gray-50">
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->country)->name ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->network)->name ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->networkMnc)->mcc_mnc ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->supplier)->name ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->connection)->name ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->connection)->username ?? '—' }}
                                </td>
                                <td class="px-3 py-2 text-right whitespace-nowrap">
                                    {{ $trimPrice($offer->price) ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->productTypeDropdown)->label ?? ($offer->product_type ?? '—') }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->knownHopsDropdown)->label ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->senderIdSupportedDropdown)->label ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @if($offer->charge_type)
                                        {{ ucwords(str_replace('_', ' ', $offer->charge_type)) }}
                                    @else
                                        —
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @if($offer->effective_date)
                                        {{ $offer->effective_date->timezone('Europe/Athens')->format('Y-m-d') }}
                                    @else
                                        —
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @if($offer->updated_at)
                                        {{ $offer->updated_at->timezone('Europe/Athens')->format('Y-m-d H:i') }}
                                    @else
                                        —
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->updater)->name ?? '—' }}
                                </td>
                                <td class="px-3 py-2 text-right whitespace-nowrap">
                                    <div class="inline-flex items-center gap-2">
                                        <a href="{{ route('offers.edit', $offer) }}"
                                           class="text-blue-600 hover:underline text-sm">
                                            Edit
                                        </a>
                                        <form method="POST"
                                              action="{{ route('offers.destroy', $offer) }}"
                                              onsubmit="return confirm('Are you sure you want to delete this offer?');"
                                              class="inline-block">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit"
                                                    class="text-red-600 hover:underline text-sm">
                                                Delete
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="15" class="px-3 py-4 text-center text-gray-500">
                                    No offers found.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div class="mt-4">
                {{ $offers->withQueryString()->links() }}
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const countryData      = @json($countryData);
            const countryInput     = document.getElementById('filter_country_name');
            const countryIdHidden  = document.getElementById('filter_country_id');
            const networkSelect    = document.getElementById('filter_network_id');

            if (!countryInput || !countryIdHidden || !networkSelect) {
                return;
            }

            function getCountryLabelById(id) {
                if (!id) return '';
                const item = countryData.find(c => String(c.id) === String(id));
                return item ? item.label : '';
            }

            function getCountryIdByLabel(label) {
                if (!label) return '';
                const trimmed = label.trim().toLowerCase();
                const item = countryData.find(c => c.label.trim().toLowerCase() === trimmed);
                return item ? item.id : '';
            }

            const initialCountryId = countryIdHidden.value;
            if (initialCountryId) {
                const label = getCountryLabelById(initialCountryId);
                if (label) {
                    countryInput.value = label;
                }
            }

            function filterNetworks() {
                const cid = countryIdHidden.value;

                Array.from(networkSelect.options).forEach(option => {
                    if (option.value === '') {
                        option.hidden = false;
                        return;
                    }
                    const optCountry = option.getAttribute('data-country-id') || '';
                    option.hidden = cid && optCountry && String(optCountry) !== String(cid);
                });

                const selected = networkSelect.selectedOptions[0];
                if (selected && selected.hidden) {
                    networkSelect.value = '';
                }
            }

            function syncCountryIdFromInput() {
                const label = countryInput.value;
                const id    = getCountryIdByLabel(label);
                countryIdHidden.value = id || '';
                filterNetworks();
            }

            countryInput.addEventListener('blur', syncCountryIdFromInput);

            countryInput.addEventListener('keydown', function (e) {
                if (e.key === 'Enter') {
                    syncCountryIdFromInput();
                }
            });

            filterNetworks();
        });
    </script>
</x-app-layout>
BLADE

########################################
# Rewrite resources/views/offers/edit.blade.php
########################################
cat > resources/views/offers/edit.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ ($offer ?? null) && $offer->exists ? 'Edit Offer' : 'Create Offer' }}
        </h2>
    </x-slot>

    @php
        $isEdit = ($offer ?? null) && $offer->exists;

        $selectedProductTypeId       = $selectedProductTypeId       ?? null;
        $selectedKnownHopsId         = $selectedKnownHopsId         ?? null;
        $selectedSenderIdSupportedId = $selectedSenderIdSupportedId ?? null;

        $existingChargeTypes = \App\Models\SupplierOffer::query()
            ->select('charge_type')
            ->whereNotNull('charge_type')
            ->distinct()
            ->orderBy('charge_type')
            ->pluck('charge_type');

        $knownChargeTypes = collect(['per_submit', 'per_delivered']);
        $chargeTypeOptions = $knownChargeTypes
            ->merge($existingChargeTypes)
            ->filter()
            ->unique()
            ->sort()
            ->values();

        $networkMncs = $networkMncs ?? collect();
        if (!($networkMncs instanceof \Illuminate\Support\Collection)) {
            $networkMncs = collect($networkMncs);
        }
        $networkMncLabelsByNetwork = $networkMncs->groupBy('network_id')->map(function ($items) {
            return $items->pluck('mcc_mnc')->unique()->values();
        });

        $defaultEffectiveDate = old('effective_date');
        if (!$defaultEffectiveDate) {
            if ($isEdit && $offer->effective_date) {
                $defaultEffectiveDate = $offer->effective_date->format('Y-m-d');
            } else {
                $defaultEffectiveDate = now()->format('Y-m-d');
            }
        }
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
                id="offer-main-form"
                method="POST"
                action="{{ $isEdit ? route('offers.update', $offer) : route('offers.store') }}"
            >
                @csrf
                @if($isEdit)
                    @method('PUT')
                @endif

                <div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:1rem;">
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

                    <div>
                        <label for="network_mnc_id" class="block text-sm font-medium text-gray-700">MCCMNC</label>
                        <select id="network_mnc_id" name="network_mnc_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                                required>
                            <option value="">
                                @if($isEdit && $offer->network_mnc_id)
                                    Loading...
                                @else
                                    Select network first
                                @endif
                            </option>
                        </select>
                        <p class="mt-1 text-xs text-gray-500">
                            A supplier offer refers to exactly one MCCMNC.
                        </p>
                    </div>

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
                </div>

                <div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:1rem;margin-top:1rem;">
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

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Connection Username</label>
                        <input id="connection_username"
                               type="text"
                               value="{{ optional($offer->connection)->username }}"
                               class="mt-1 block w-full border-gray-300 rounded-md shadow-sm bg-gray-100 text-gray-700"
                               readonly>
                    </div>

                    <div>
                        <label for="price" class="block text-sm font-medium text-gray-700">Price</label>
                        <input id="price"
                               name="price"
                               type="text"
                               value="{{ old('price', $offer->price_trimmed ?? $offer->price) }}"
                               class="mt-1 block w-full border-gray-300 rounded-md shadow-sm {{ $isEdit ? 'bg-gray-100 text-gray-700 cursor-not-allowed' : '' }}"
                               {{ $isEdit ? 'readonly' : '' }}
                               required>
                        <p class="mt-1 text-xs text-gray-500">
                            Stored trimmed (e.g. 0.03500 → 0.035).
                        </p>
                    </div>

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
                </div>

                <div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:1rem;margin-top:1rem;">
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

                    <div>
                        <label for="effective_date" class="block text-sm font-medium text-gray-700">Effective Date</label>
                        <input id="effective_date"
                               name="effective_date"
                               type="date"
                               value="{{ $defaultEffectiveDate }}"
                               class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                               required>
                    </div>
                </div>

                <div class="mt-4">
                    <div class="flex items-center">
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
                </div>
            </form>

            <div class="mt-4 flex justify-end items-center gap-2">
                <a href="{{ route('offers.index') }}"
                   class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm bg-white text-gray-700 hover:bg-gray-50">
                    Back to Offers
                </a>

                <button type="submit"
                        form="offer-main-form"
                        class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                    {{ $isEdit ? 'Save Changes' : 'Create Offer' }}
                </button>

                @if($isEdit)
                    <form method="POST"
                          action="{{ route('offers.destroy', $offer) }}"
                          onsubmit="return confirm('Are you sure you want to delete this offer?');"
                          class="inline-block">
                        @csrf
                        @method('DELETE')
                        <button type="submit"
                                class="inline-flex items-center px-4 py-2 border border-red-600 text-sm font-medium rounded-md shadow-sm bg-white text-red-600 hover:bg-red-50">
                            Delete
                        </button>
                    </form>
                @endif
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const countrySelect            = document.getElementById('country_id');
            const networkSelect            = document.getElementById('network_id');
            const mncSelect                = document.getElementById('network_mnc_id');
            const connectionSelect         = document.getElementById('supplier_connection_id');
            const productTypeSelect        = document.getElementById('product_type_id');
            const chargeTypeSelect         = document.getElementById('charge_type');
            const mccInfo                  = document.getElementById('network_mccmnc_info');
            const connectionUsernameInput  = document.getElementById('connection_username');

            const mncsEndpointBase   = "{{ url('/offers/network') }}";
            const connDefaultsBase   = "{{ url('/offers/connection') }}";
            const oldMncId           = "{{ old('network_mnc_id', $offer->network_mnc_id ?? '') }}";

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
                        placeholder.textContent = mncs.length ? 'Select MCCMNC' : 'Select network first';
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

                        // auto-select όταν υπάρχει μόνο ένα MCCMNC και δεν υπάρχει προηγούμενη τιμή
                        if (!oldMncId && mncs.length === 1) {
                            mncSelect.value = mncs[0].id;
                        }

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
                        opt.textContent = '(error loading MCCMNCs)';
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

                if (chargeTypeSelect && chargeTypeAttr) {
                    const opt = Array.from(chargeTypeSelect.options).find(o => o.value === chargeTypeAttr);
                    if (opt) {
                        chargeTypeSelect.value = chargeTypeAttr;
                    }
                }

                if (connectionUsernameInput) {
                    connectionUsernameInput.value = connUsername;
                }

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

            filterNetworksByCountry();
            loadMncsForNetwork();
            applyConnectionDefaults();
        });
    </script>
</x-app-layout>
BLADE

echo "==> Done. Backups in: ${BACKUP_DIR}"
