#!/usr/bin/env bash

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_index_body_btn_$(date +%F_%H-%M-%S)"

echo "==> Backing up current offers index view into ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/resources/views/offers"
if [ -f "resources/views/offers/index.blade.php" ]; then
  cp resources/views/offers/index.blade.php "${BACKUP_DIR}/resources/views/offers/" 2>/dev/null || true
else
  echo "WARNING: resources/views/offers/index.blade.php not found; will create a new one from scratch."
fi

echo "==> Rewriting resources/views/offers/index.blade.php with body-level Create Offer button"

cat > resources/views/offers/index.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offers
        </h2>
    </x-slot>

    {{-- FULL WIDTH PAGE --}}
    <div class="py-6 w-full max-w-full px-2 sm:px-4 lg:px-6 mx-auto">
        @if (session('status'))
            <div class="mb-4 bg-green-50 border border-green-200 text-green-800 px-4 py-3 rounded text-sm">
                {{ session('status') }}
            </div>
        @endif

        {{-- Filters + Create Offer button --}}
        <div class="bg-white p-4 rounded-lg shadow mb-4 w-full">
            <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-gray-800">
                    Filters
                </h3>
                <a href="{{ route('offers.create') }}"
                   class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-green-600 text-white hover:bg-green-700">
                    + Create Offer
                </a>
            </div>

            <form method="GET" action="{{ route('offers.index') }}" class="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-4 items-end">
                {{-- Country --}}
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

                {{-- Network --}}
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

                {{-- Supplier --}}
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

                {{-- Connection --}}
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

                {{-- Product Type --}}
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

                {{-- Known Hops --}}
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

                {{-- Sender ID Supported --}}
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

                {{-- Charge Type --}}
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

                {{-- Buttons --}}
                <div class="flex gap-2">
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                        Filter
                    </button>
                    <a href="{{ route('offers.index') }}"
                       class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm bg-white text-gray-700 hover:bg-gray-50">
                        Clear
                    </a>
                </div>
            </form>
        </div>

        {{-- Table with horizontal scroll --}}
        <div class="bg-white rounded-lg shadow overflow-x-auto w-full">
            <table class="min-w-max divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Country</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Network</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">MCC/MNC</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Supplier</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Connection</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Conn. Username</th>
                        <th class="px-3 py-2 text-right font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Price</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Product Type</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Known Hops</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Sender ID Supported</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Charge Type</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Last Edited</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Edited By</th>
                        <th class="px-3 py-2"></th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                    @forelse($offers as $offer)
                        <tr>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->country)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->network)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                @if($offer->mcc_mnc)
                                    {{ $offer->mcc_mnc }}
                                @elseif($offer->networkMnc)
                                    {{ $offer->networkMnc->mcc_mnc }}
                                @else
                                    -
                                @endif
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->supplier)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->connection)->name ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->connection)->username ?? '-' }}
                            </td>
                            <td class="px-3 py-2 text-right whitespace-nowrap">
                                {{ $offer->price_trimmed ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ $offer->product_type_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ $offer->known_hops_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ $offer->sender_id_supported_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ $offer->charge_type_label ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ optional($offer->updated_at)->format('Y-m-d H:i') ?? '-' }}
                            </td>
                            <td class="px-3 py-2 whitespace-nowrap">
                                {{ $offer->updated_by_user_id ?? '-' }}
                            </td>
                            <td class="px-3 py-2 text-right whitespace-nowrap">
                                <a href="{{ route('offers.edit', $offer) }}"
                                   class="text-blue-600 hover:text-blue-900 text-sm">
                                    Edit
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="14" class="px-3 py-4 text-center text-gray-500">
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

echo "==> DONE. Backup stored at ${BACKUP_DIR}"
