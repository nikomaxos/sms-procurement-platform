<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offers
        </h2>
    </x-slot>

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">

        @if (session('status'))
            <div class="bg-green-100 border border-green-400 text-green-800 px-4 py-2 rounded">
                {{ session('status') }}
            </div>
        @endif

        <!-- Filters -->
        <div class="bg-white shadow-sm rounded-lg p-4">
            <form method="GET" action="{{ route('offers.index') }}" class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Country</label>
                        <select name="country_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                            <option value="">All</option>
                            @foreach ($countries as $country)
                                <option value="{{ $country->id }}" @selected(request('country_id') == $country->id)>
                                    {{ $country->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Network</label>
                        <select name="network_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                            <option value="">All</option>
                            @foreach ($networks as $network)
                                <option value="{{ $network->id }}" @selected(request('network_id') == $network->id)>
                                    {{ $network->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Supplier</label>
                        <select name="supplier_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                            <option value="">All</option>
                            @foreach ($suppliers as $supplier)
                                <option value="{{ $supplier->id }}" @selected(request('supplier_id') == $supplier->id)>
                                    {{ $supplier->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Connection</label>
                        <select name="supplier_connection_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                            <option value="">All</option>
                            @foreach ($connections as $connection)
                                <option value="{{ $connection->id }}" @selected(request('supplier_connection_id') == $connection->id)>
                                    {{ $connection->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Exclusive</label>
                        <select name="is_exclusive" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                            <option value="">All</option>
                            <option value="1" @selected(request('is_exclusive') === '1')>Yes</option>
                            <option value="0" @selected(request('is_exclusive') === '0')>No</option>
                        </select>
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Product Type</label>
                        <select name="product_type" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                            <option value="">All</option>
                            @foreach ($productTypeFilterOptions as $opt)
                                <option value="{{ $opt }}" @selected(request('product_type') === $opt)>{{ $opt }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Known Hops</label>
                        <select name="known_hops" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                            <option value="">All</option>
                            @foreach ($knownHopsFilterOptions as $opt)
                                <option value="{{ $opt }}" @selected(request('known_hops') === $opt)>{{ $opt }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700">Sender ID Supported</label>
                        <select name="sender_id_supported" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                            <option value="">All</option>
                            @foreach ($senderIdFilterOptions as $opt)
                                <option value="{{ $opt }}" @selected(request('sender_id_supported') === $opt)>{{ $opt }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div class="flex items-end">
                        <button type="submit" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700">
                            Apply filters
                        </button>
                    </div>

                    <div class="flex items-end">
                        <a href="{{ route('offers.index') }}" class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50">
                            Reset
                        </a>
                    </div>
                </div>
            </form>
        </div>

        <!-- Actions -->
        <div class="flex justify-between items-center">
            <a href="{{ route('offers.create') }}" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700">
                + New Offer
            </a>
        </div>

        <!-- Offers table -->
        <div class="bg-white shadow-sm rounded-lg overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-3 py-2 text-left font-medium text-gray-500">Country</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500">Network</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500">MCC-MNC</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500">Supplier</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500">Connection</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500">Product Type</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500">Known Hops</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500">Sender ID Supported</th>
                        <th class="px-3 py-2 text-right font-medium text-gray-500">Price</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500">Charge Type</th>
                        <th class="px-3 py-2 text-center font-medium text-gray-500">Exclusive</th>
                        <th class="px-3 py-2 text-left font-medium text-gray-500">Effective Date</th>
                        <th class="px-3 py-2 text-right font-medium text-gray-500">Actions</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-200">
                    @forelse ($offers as $offer)
                        <tr>
                            <td class="px-3 py-2">{{ $offer->country->name ?? '' }}</td>
                            <td class="px-3 py-2">{{ $offer->network->name ?? '' }}</td>
                            <td class="px-3 py-2">
                                @if ($offer->mcc && $offer->mnc)
                                    {{ $offer->mcc }}{{ str_pad($offer->mnc, 2, '0', STR_PAD_LEFT) }}
                                @elseif($offer->networkMnc)
                                    {{ $offer->networkMnc->mcc_mnc }}
                                @endif
                            </td>
                            <td class="px-3 py-2">{{ $offer->supplier->name ?? '' }}</td>
                            <td class="px-3 py-2">{{ $offer->connection_name }}</td>
                            <td class="px-3 py-2">{{ $offer->product_type }}</td>
                            <td class="px-3 py-2">{{ $offer->known_hops }}</td>
                            <td class="px-3 py-2">{{ $offer->sender_id_supported }}</td>
                            <td class="px-3 py-2 text-right">{{ $offer->price }}</td>
                            <td class="px-3 py-2">{{ $offer->charge_type }}</td>
                            <td class="px-3 py-2 text-center">
                                @if ($offer->is_exclusive)
                                    <span class="text-green-600 font-semibold">Yes</span>
                                @else
                                    <span class="text-gray-400">No</span>
                                @endif
                            </td>
                            <td class="px-3 py-2">
                                {{ optional($offer->effective_date)->format('Y-m-d') }}
                            </td>
                            <td class="px-3 py-2 text-right space-x-2 whitespace-nowrap">
                                <a href="{{ route('offers.edit', $offer) }}" class="text-indigo-600 hover:text-indigo-900">Edit</a>
                                <form action="{{ route('offers.destroy', $offer) }}" method="POST" class="inline">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="text-red-600 hover:text-red-900" onclick="return confirm('Delete this offer?')">
                                        Delete
                                    </button>
                                </form>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="13" class="px-3 py-4 text-center text-gray-500">
                                No offers found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div>
            {{ $offers->links() }}
        </div>
    </div>
</x-app-layout>
