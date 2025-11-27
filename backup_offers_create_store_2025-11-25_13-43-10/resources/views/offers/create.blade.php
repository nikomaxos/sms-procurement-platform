<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Create Offer
        </h2>
    </x-slot>

    <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-white shadow-sm rounded-lg p-6">
            <a href="{{ route('offers.index') }}" class="text-sm text-indigo-600 hover:underline">&larr; Back to offers</a>

            <form method="POST" action="{{ route('offers.store') }}" class="mt-4 space-y-6">
                @csrf

                @if ($errors->any())
                    <div class="bg-red-100 border border-red-400 text-red-800 px-4 py-2 rounded">
                        <div class="font-semibold mb-1">There were some problems with your input:</div>
                        <ul class="list-disc list-inside text-sm">
                            @foreach ($errors->all() as $error)
                                <li>{{ $error }}</li>
                            @endforeach
                        </ul>
                    </div>
                @endif

                <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Country</label>
                        <select name="country_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                            <option value="">Select...</option>
                            @foreach ($countries as $country)
                                <option value="{{ $country->id }}" @selected(old('country_id') == $country->id)>{{ $country->name }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Network</label>
                        <select name="network_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                            <option value="">Select...</option>
                            @foreach ($networks as $network)
                                <option value="{{ $network->id }}" @selected(old('network_id') == $network->id)>{{ $network->name }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Network MNC (MCC/MNC)</label>
                        <select name="network_mnc_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                            <option value="">Select...</option>
                            @foreach (\App\Models\NetworkMnc::orderBy('mcc_mnc')->get() as $nm)
                                <option value="{{ $nm->id }}" @selected(old('network_mnc_id') == $nm->id)>
                                    {{ $nm->mcc_mnc }} - {{ $nm->network->name ?? '' }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Supplier</label>
                        <select name="supplier_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                            <option value="">Select...</option>
                            @foreach ($suppliers as $supplier)
                                <option value="{{ $supplier->id }}" @selected(old('supplier_id') == $supplier->id)>{{ $supplier->name }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Connection</label>
                        <select name="supplier_connection_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                            <option value="">Select...</option>
                            @foreach ($connections as $connection)
                                <option value="{{ $connection->id }}" @selected(old('supplier_connection_id') == $connection->id)>
                                    {{ $connection->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Product Type</label>
                        <select name="product_type_dropdown_item_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                            <option value="">Select...</option>
                            @foreach ($productTypeOptions as $id => $label)
                                <option value="{{ $id }}" @selected(old('product_type_dropdown_item_id') == $id)>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Known Hops</label>
                        <select name="known_hops_dropdown_item_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                            <option value="">Select...</option>
                            @foreach ($knownHopsOptions as $id => $label)
                                <option value="{{ $id }}" @selected(old('known_hops_dropdown_item_id') == $id)>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Sender ID Supported</label>
                        <select name="sender_id_supported_dropdown_item_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                            <option value="">Select...</option>
                            @foreach ($senderIdOptions as $id => $label)
                                <option value="{{ $id }}" @selected(old('sender_id_supported_dropdown_item_id') == $id)>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Charge Type</label>
                        <input type="text" name="charge_type" value="{{ old('charge_type', 'per_submit') }}" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Price</label>
                        <input type="text" name="price" value="{{ old('price') }}" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Effective Date</label>
                        <input type="date" name="effective_date" value="{{ old('effective_date', now()->toDateString()) }}" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                    </div>

                    <div class="flex items-center mt-6">
                        <input id="is_exclusive" name="is_exclusive" type="checkbox" value="1" class="h-4 w-4 text-indigo-600 border-gray-300 rounded" @checked(old('is_exclusive'))>
                        <label for="is_exclusive" class="ml-2 block text-sm text-gray-700">
                            Exclusive
                        </label>
                    </div>
                </div>

                <div class="flex justify-end">
                    <button type="submit" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700">
                        Save Offer
                    </button>
                </div>
            </form>
        </div>
    </div>
</x-app-layout>
