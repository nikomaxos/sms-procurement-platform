<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offers
        </h2>
    </x-slot>

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

        {{-- Filters --}}
        @include('offers.partials.filters')

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
</x-app-layout>
