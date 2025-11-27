<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offer History
        </h2>
    </x-slot>

    <div class="py-6 max-w-5xl mx-auto sm:px-6 lg:px-8">
        <div class="mb-4 bg-white shadow-sm rounded-lg p-4 text-sm">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
                <div>
                    <div class="text-gray-500">Supplier</div>
                    <div class="text-gray-900 font-medium">{{ $offer->supplier?->name }}</div>
                </div>
                <div>
                    <div class="text-gray-500">Connection</div>
                    <div class="text-gray-900 font-medium">{{ $offer->connection?->name }}</div>
                </div>
                <div>
                    <div class="text-gray-500">Country / Network</div>
                    <div class="text-gray-900">
                        {{ $offer->country?->name }} — {{ $offer->network?->name }}
                    </div>
                </div>
                <div>
                    <div class="text-gray-500">MCCMNC</div>
                    <div class="text-gray-900">{{ $offer->mcc_mnc }}</div>
                </div>
            </div>
        </div>

        <div class="bg-white shadow-sm rounded-lg overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Price
                        </th>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Effective Date
                        </th>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Product Type
                        </th>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Charge Type
                        </th>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Is Exclusive
                        </th>
                    </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                    @forelse($history as $row)
                        <tr>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                {{ number_format((float) $row->price, 6) }}
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                {{ $row->effective_date?->format('Y-m-d') }}
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                {{ $row->product_type }}
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                @if($row->charge_type === 'per_submit')
                                    Per Submit
                                @elseif($row->charge_type === 'per_delivered')
                                    Per Delivered
                                @else
                                    {{ $row->charge_type }}
                                @endif
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                @if($row->is_exclusive)
                                    Yes
                                @else
                                    No
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="px-4 py-4 text-center text-sm text-gray-500">
                                No historic prices recorded for this offer yet.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div class="mt-4">
            <a href="{{ route('offers.index') }}"
               class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md text-sm text-gray-700 bg-white hover:bg-gray-50">
                Back to Offers
            </a>
        </div>
    </div>
</x-app-layout>
