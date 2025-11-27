<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offers
        </h2>
    </x-slot>

    @php
        $selectedCountryId    = request('country_id');
        $selectedNetworkId    = request('network_id');
        $selectedSupplierId   = request('supplier_id');
        $selectedConnectionId = request('supplier_connection_id');
        $selectedProductType  = request('product_type');
        $selectedKnownHopsId  = request('known_hops_dropdown_item_id');
        $selectedSenderIdId   = request('sender_id_supported_dropdown_item_id');
        $selectedChargeType   = request('charge_type');

        $selectedCountry = $countries->firstWhere('id', $selectedCountryId);
    @endphp

    <div class="py-6 w-full max-w-full px-2 sm:px-4 lg:px-6 mx-auto">
        @if (session('status'))
            <div class="mb-4 bg-green-50 border border-green-200 text-green-800 px-4 py-3 rounded text-sm">
                {{ session('status') }}
            </div>
        @endif

        <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold text-gray-800">Supplier Offers</h3>
            <a href="{{ route('offers.create') }}"
               class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                Create Offer
            </a>
        </div>

        {{-- Filters (inline, no partial) --}}
        <form method="GET"
              action="{{ route('offers.index') }}"
              class="bg-white mb-4 rounded-lg shadow p-4">
            <div class="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
                {{-- Country search + select --}}
                <div>
                    <label for="country_search" class="block text-sm font-medium text-gray-700">Country</label>
                    <input
                        id="country_search"
                        type="text"
                        class="mt-1 block w-full border-gray-300 rounded-md shadow-sm text-sm"
                        placeholder="Search country..."
                        value="{{ $selectedCountry?->name }}"
                    >
                    <select
                        id="country_id"
                        name="country_id"
                        class="mt-1 block w-full border-gray-300 rounded-md shadow-sm text-sm"
                    >
                        <option value="">All countries</option>
                        @foreach($countries as $country)
                            <option value="{{ $country->id }}" @selected($selectedCountryId == $country->id)>
                                {{ $country->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Network --}}
                <div>
                    <label for="network_id" class="block text-sm font-medium text-gray-700">Network</label>
                    <select id="network_id" name="network_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm text-sm">
                        <option value="">All networks</option>
                        @foreach($networks as $network)
                            <option value="{{ $network->id }}" @selected($selectedNetworkId == $network->id)>
                                {{ $network->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Supplier --}}
                <div>
                    <label for="supplier_id" class="block text-sm font-medium text-gray-700">Supplier</label>
                    <select id="supplier_id" name="supplier_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm text-sm">
                        <option value="">All suppliers</option>
                        @foreach($suppliers as $supplier)
                            <option value="{{ $supplier->id }}" @selected($selectedSupplierId == $supplier->id)>
                                {{ $supplier->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Supplier Connection --}}
                <div>
                    <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">Connection</label>
                    <select id="supplier_connection_id" name="supplier_connection_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm text-sm">
                        <option value="">All connections</option>
                        @foreach($connections as $connection)
                            <option value="{{ $connection->id }}" @selected($selectedConnectionId == $connection->id)>
                                {{ $connection->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Product Type (string from offers) --}}
                <div>
                    <label for="product_type" class="block text-sm font-medium text-gray-700">Product Type</label>
                    <select id="product_type" name="product_type"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm text-sm">
                        <option value="">All types</option>
                        @foreach($productTypeFilterOptions as $pt)
                            <option value="{{ $pt }}" @selected($selectedProductType === $pt)>
                                {{ $pt }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Known Hops --}}
                <div>
                    <label for="known_hops_dropdown_item_id" class="block text-sm font-medium text-gray-700">
                        Known Hops
                    </label>
                    <select id="known_hops_dropdown_item_id" name="known_hops_dropdown_item_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm text-sm">
                        <option value="">All</option>
                        @foreach($knownHopsFilterOptions as $item)
                            <option value="{{ $item->id }}" @selected($selectedKnownHopsId == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Sender ID Supported --}}
                <div>
                    <label for="sender_id_supported_dropdown_item_id"
                           class="block text-sm font-medium text-gray-700">
                        Sender ID Supported
                    </label>
                    <select id="sender_id_supported_dropdown_item_id" name="sender_id_supported_dropdown_item_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm text-sm">
                        <option value="">All</option>
                        @foreach($senderIdFilterOptions as $item)
                            <option value="{{ $item->id }}" @selected($selectedSenderIdId == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Charge Type --}}
                <div>
                    <label for="charge_type" class="block text-sm font-medium text-gray-700">
                        Charge Type
                    </label>
                    <select id="charge_type" name="charge_type"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm text-sm">
                        <option value="">All</option>
                        @foreach($chargeTypeFilterOptions as $ct)
                            <option value="{{ $ct }}" @selected($selectedChargeType === $ct)>
                                {{ ucwords(str_replace('_', ' ', $ct)) }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Actions --}}
                <div class="mt-4 col-span-1 md:col-span-3 lg:col-span-5 flex justify-end gap-2">
                    <a href="{{ route('offers.index') }}"
                       class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md shadow-sm bg-white text-gray-700 hover:bg-gray-50">
                        Reset
                    </a>
                    <button type="submit"
                            class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                        Apply Filters
                    </button>
                </div>
            </div>
        </form>

        {{-- Results table --}}
        <div class="mt-4 bg-white rounded-lg shadow">
            <div class="overflow-x-auto">
                <table class="min-w-full table-auto text-sm">
                    <thead class="bg-gray-50">
                        <tr>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Country</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Network</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">MCC/MNC</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Supplier</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Connection</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Conn. Username</th>
                            <th class="px-3 py-2 text-right text-xs font-semibold text-gray-600 uppercase tracking-wider">Price</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Product Type</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Known Hops</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Sender ID Supported</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Charge Type</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Effective Date</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Last Edited (GR)</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Edited By</th>
                            <th class="px-3 py-2 text-right text-xs font-semibold text-gray-600 uppercase tracking-wider">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($offers as $offer)
                            <tr class="border-t border-gray-200">
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->country)->name }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->network)->name }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @if($offer->networkMnc)
                                        {{ $offer->networkMnc->mcc_mnc }}
                                    @else
                                        {{ $offer->mcc_mnc }}
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->supplier)->name }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->connection)->name }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->connection)->username }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap text-right">
                                    {{ $offer->price_trimmed ?? $offer->price }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @if($offer->productTypeDropdown)
                                        {{ $offer->productTypeDropdown->label }}
                                    @else
                                        {{ $offer->product_type }}
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->knownHopsDropdown)->label }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->senderIdSupportedDropdown)->label }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @if($offer->charge_type)
                                        {{ ucwords(str_replace('_', ' ', $offer->charge_type)) }}
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @if($offer->effective_date)
                                        {{ $offer->effective_date->format('Y-m-d') }}
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @if($offer->updated_at)
                                        {{ $offer->updated_at->timezone('Europe/Athens')->format('Y-m-d H:i') }}
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->updatedBy)->name }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap text-right">
                                    <a href="{{ route('offers.edit', $offer) }}"
                                       class="inline-flex items-center px-2 py-1 border border-gray-300 rounded-md text-xs text-gray-700 hover:bg-gray-50">
                                        Edit
                                    </a>
                                    <form action="{{ route('offers.destroy', $offer) }}"
                                          method="POST"
                                          class="inline-block ml-1"
                                          onsubmit="return confirm('Are you sure you want to delete this offer?');">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit"
                                                class="inline-flex items-center px-2 py-1 border border-red-600 rounded-md text-xs text-red-600 hover:bg-red-50">
                                            Delete
                                        </button>
                                    </form>
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

            <div class="px-4 py-3 border-t bg-gray-50">
                {{ $offers->links() }}
            </div>
        </div>
    </div>

    <script>
        // Simple "search while typing" for country select
        document.addEventListener('DOMContentLoaded', function () {
            const searchInput  = document.getElementById('country_search');
            const countrySelect = document.getElementById('country_id');

            if (!searchInput || !countrySelect) return;

            function filterCountryOptions() {
                const term = searchInput.value.toLowerCase();
                Array.from(countrySelect.options).forEach(option => {
                    if (!option.value) {
                        // keep "All countries" always visible
                        option.hidden = false;
                        return;
                    }
                    const text = option.text.toLowerCase();
                    option.hidden = term && !text.includes(term);
                });
            }

            searchInput.addEventListener('input', filterCountryOptions);
        });
    </script>
</x-app-layout>
