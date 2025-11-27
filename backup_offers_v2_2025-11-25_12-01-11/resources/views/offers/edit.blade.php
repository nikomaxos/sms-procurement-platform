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

                        <div>
                            <label for="network_id" class="block text-sm font-medium text-gray-700">Network</label>
                            <select id="network_id" name="network_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                @foreach($networks as $network)
                                    <option value="{{ $network->id }}" @selected(old('network_id', $offer->network_id) == $network->id)>
                                        {{ $network->name }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

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

                        <div>
                            <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">Connection</label>
                            <select id="supplier_connection_id" name="supplier_connection_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">—</option>
                                @foreach($connections as $connection)
                                    <option value="{{ $connection->id }}" @selected(old('supplier_connection_id', $offer->supplier_connection_id) == $connection->id)>
                                        {{ $connection->name }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        <div>
                            <label for="network_mnc_id" class="block text-sm font-medium text-gray-700">MCC / MNC</label>
                            <select id="network_mnc_id" name="network_mnc_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">—</option>
                                @foreach($networkMncs as $nm)
                                    <option value="{{ $nm->id }}" @selected(old('network_mnc_id', $offer->network_mnc_id) == $nm->id)>
                                        {{ $nm->mcc_mnc }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        <div>
                            <label for="price" class="block text-sm font-medium text-gray-700">Price</label>
                            <input type="number" step="0.00001" min="0" name="price" id="price" value="{{ old('price', $offer->price) }}" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        </div>

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
                        </div>

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

                        <div>
                            <label for="charge_type" class="block text-sm font-medium text-gray-700">Charge Type</label>
                            <input type="text" name="charge_type" id="charge_type" value="{{ old('charge_type', $offer->charge_type) }}" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        </div>

                        <div class="flex items-center mt-6">
                            <input id="is_exclusive" name="is_exclusive" type="checkbox" value="1" class="h-4 w-4 text-blue-600 border-gray-300 rounded"
                                   @checked(old('is_exclusive', $offer->is_exclusive))>
                            <label for="is_exclusive" class="ml-2 block text-sm text-gray-700">
                                Exclusive
                            </label>
                        </div>

                        <div>
                            <label for="effective_date" class="block text-sm font-medium text-gray-700">Effective Date</label>
                            <input type="date" name="effective_date" id="effective_date" value="{{ old('effective_date', optional($offer->effective_date)->format('Y-m-d')) }}" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
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
</x-app-layout>
