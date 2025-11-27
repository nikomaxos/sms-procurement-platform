<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ __('Offers') }}
        </h2>
    </x-slot>

    @php







        $countryOptions = \App\Models\Country::orderBy('name')->get();
        $countryNames = $countryOptions->pluck('name', 'id');

        $networkOptions = \App\Models\Network::orderBy('name')->get();
        $networkNames = $networkOptions->pluck('name', 'id');

        $supplierOptions = \App\Models\Supplier::orderBy('name')->get();
        $supplierNames = $supplierOptions->pluck('name', 'id');

        $connectionOptions = \App\Models\SupplierConnection::orderBy('name')->get();
        $connectionNames = $connectionOptions->pluck('name', 'id');
        $connectionUsernames = $connectionOptions->pluck('username', 'id');

        // Dropdown menus (Product Type, Known Hops, Sender Id Supported)
        $productTypes = \App\Models\DropdownItem::whereHas('menu', fn($q) => $q->where('id', 1))
            ->orderBy('position')->orderBy('label')->get();
        $productTypeLabels = $productTypes->pluck('label', 'id');

        $knownHopsOptions = \App\Models\DropdownItem::whereHas('menu', fn($q) => $q->where('id', 2))
            ->orderBy('position')->orderBy('label')->get();
        $knownHopsLabels = $knownHopsOptions->pluck('label', 'id');

        $senderIdOptions = \App\Models\DropdownItem::whereHas('menu', fn($q) => $q->where('id', 3))
            ->orderBy('position')->orderBy('label')->get();
        $senderIdLabels = $senderIdOptions->pluck('label', 'id');

        // Charge models
        $chargeModelOptions = \Illuminate\Support\Facades\DB::table('charge_models')->orderBy('name')->get();
        $chargeModelLabels = $chargeModelOptions->pluck('name', 'id');
    @endphp

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
        @if (session('status'))
            <div class="bg-green-50 border border-green-200 text-green-800 text-sm px-4 py-2 rounded-md">
                {{ session('status') }}
            </div>
        @endif

        @if (session('error'))
            <div class="bg-red-50 border border-red-200 text-red-800 text-sm px-4 py-2 rounded-md">
                {{ session('error') }}
            </div>
        @endif

        <!-- Filters (packed into grid; on xl+ ~2 rows) -->
        <div class="bg-white shadow rounded-lg p-4">
            <form method="GET" action="{{ route('offers.index') }}" class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 2xl:grid-cols-8 gap-3 text-sm">
                    <!-- Country -->
                    <div class="flex flex-col">
                        <label for="filter_country_id" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('Country') }}
                        </label>
                        <select id="filter_country_id" name="country_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach($countryOptions as $country)
                                <option value="{{ $country->id }}" @selected((string)request('country_id') === (string)$country->id)>
                                    {{ $country->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- Network -->
                    <div class="flex flex-col">
                        <label for="filter_network_id" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('Network') }}
                        </label>
                        <select id="filter_network_id" name="network_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach($networkOptions as $network)
                                <option value="{{ $network->id }}" @selected((string)request('network_id') === (string)$network->id)>
                                    {{ $network->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- MCCMNC -->
                    <div class="flex flex-col">
                        <label for="filter_mcc_mnc" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('MCCMNC') }}
                        </label>
                        <input id="filter_mcc_mnc" type="text" name="mcc_mnc"
                               value="{{ request('mcc_mnc') }}"
                               placeholder="20210"
                               class="mt-1 block w-full rounded-md border-gray-300 text-sm" />
                    </div>

                    <!-- Supplier -->
                    <div class="flex flex-col">
                        <label for="filter_supplier_id" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('Supplier') }}
                        </label>
                        <select id="filter_supplier_id" name="supplier_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach($supplierOptions as $supplier)
                                <option value="{{ $supplier->id }}" @selected((string)request('supplier_id') === (string)$supplier->id)>
                                    {{ $supplier->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- Connection -->
                    <div class="flex flex-col">
                        <label for="filter_supplier_connection_id" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('Connection') }}
                        </label>
                        <select id="filter_supplier_connection_id" name="supplier_connection_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach($connectionOptions as $conn)
                                <option value="{{ $conn->id }}" @selected((string)request('supplier_connection_id') === (string)$conn->id)>
                                    {{ $conn->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- Username -->
                    <div class="flex flex-col">
                        <label for="filter_username" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('Username') }}
                        </label>
                        <input id="filter_username" type="text" name="username"
                               value="{{ request('username') }}"
                               class="mt-1 block w-full rounded-md border-gray-300 text-sm" />
                    </div>

                    <!-- Product Type -->
                    <div class="flex flex-col">
                        <label for="filter_product_type_id" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('Product Type') }}
                        </label>
                        <select id="filter_product_type_id" name="product_type_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach($productTypes as $item)
                                <option value="{{ $item->id }}" @selected((string)request('product_type_id') === (string)$item->id)>
                                    {{ $item->label }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- Known Hops -->
                    <div class="flex flex-col">
                        <label for="filter_known_hops_dropdown_item_id" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('Known Hops') }}
                        </label>
                        <select id="filter_known_hops_dropdown_item_id" name="known_hops_dropdown_item_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach($knownHopsOptions as $item)
                                <option value="{{ $item->id }}" @selected((string)request('known_hops_dropdown_item_id') === (string)$item->id)>
                                    {{ $item->label }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- Sender Id Supported -->
                    <div class="flex flex-col">
                        <label for="filter_sender_id_supported_dropdown_item_id" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('Sender Id Supported') }}
                        </label>
                        <select id="filter_sender_id_supported_dropdown_item_id" name="sender_id_supported_dropdown_item_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach($senderIdOptions as $item)
                                <option value="{{ $item->id }}" @selected((string)request('sender_id_supported_dropdown_item_id') === (string)$item->id)>
                                    {{ $item->label }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- Charge Type -->
                    <div class="flex flex-col">
                        <label for="filter_charge_type" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('Charge Type') }}
                        </label>
                        <select id="filter_charge_type" name="charge_type" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach(['Per Submit', 'Per Delivered'] as $ct)
                                <option value="{{ $ct }}" @selected(request('charge_type') === $ct)>
                                    {{ $ct }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- Charge Model -->
                    <div class="flex flex-col">
                        <label for="filter_charge_model_id" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('Charge Model') }}
                        </label>
                        <select id="filter_charge_model_id" name="charge_model_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach($chargeModelOptions as $item)
                                <option value="{{ $item->id }}" @selected((string)request('charge_model_id') === (string)$item->id)>
                                    {{ $item->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- Is Exclusive -->
                    <div class="flex flex-col">
                        <label for="filter_is_exclusive" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                            {{ __('Is Exclusive') }}
                        </label>
                        <select id="filter_is_exclusive" name="is_exclusive" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            <option value="1" @selected(request('is_exclusive') === '1')>{{ __('Yes') }}</option>
                            <option value="0" @selected(request('is_exclusive') === '0')>{{ __('No') }}</option>
                        </select>
                    </div>
                </div>

                <div class="flex flex-wrap items-center justify-between gap-3 pt-2">
                    <div class="flex items-center gap-2 text-sm">
                        <label for="per_page" class="font-medium text-gray-700">
                            {{ __('Per page') }}
                        </label>
                        <select id="per_page" name="per_page" class="rounded-md border-gray-300 text-sm">
                            @foreach([25, 50, 100, 200] as $size)
                                <option value="{{ $size }}" @selected((int)request('per_page', 50) === $size)>{{ $size }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div class="flex items-center gap-2">
                        <button type="submit"
                                class="inline-flex items-center px-3 py-1.5 border border-transparent rounded-md bg-indigo-600 text-white text-sm hover:bg-indigo-700">
                            {{ __('Apply filters') }}
                        </button>
                        <a href="{{ route('offers.index') }}"
                           class="inline-flex items-center px-3 py-1.5 border border-gray-300 rounded-md text-sm text-gray-700 bg-white hover:bg-gray-50">
                            {{ __('Reset') }}
                        </a>
                    </div>
                </div>
            </form>
        </div>

        <!-- Offers table + bulk update -->
        <div class="bg-white shadow rounded-lg p-4">
            <form method="POST" action="{{ route('offers.bulk_update') }}" id="offers-bulk-form" class="space-y-4">
                @csrf

                <div class="overflow-x-auto">
                    <table class="min-w-full divide-y divide-gray-200 text-sm">
                        <thead class="bg-gray-50">
                        <tr>
                            <th class="px-3 py-2">
                                <input type="checkbox" id="select_all_offers" class="rounded border-gray-300">
                            </th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Country') }}</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Network') }}</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('MCCMNC') }}</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Supplier') }}</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Connection') }}</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Username') }}</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Product Type') }}</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Known Hops') }}</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Sender Id Supported') }}</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Charge Type') }}</th>
                            <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Charge Model') }}</th>
                            <th class="px-3 py-2 text-center text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Exclusive') }}</th>
                            <th class="px-3 py-2 text-right text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Price (€)') }}</th>
                            <th class="px-3 py-2 text-right text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Effective Date') }}</th>
                            <th class="px-3 py-2 text-right text-xs font-semibold text-gray-500 uppercase tracking-wide">{{ __('Actions') }}</th>
                        </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                        @forelse($offers as $offer)
                            <tr class="hover:bg-gray-50">
                                <td class="px-3 py-2">
                                    <input type="checkbox" name="offer_ids[]" value="{{ $offer->id }}"
                                           class="offer-select rounded border-gray-300">
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">{{ $countryNames[$offer->country_id] ?? '—' }}</td>
                                <td class="px-3 py-2 whitespace-nowrap">{{ $networkNames[$offer->network_id] ?? '—' }}</td>
                                <td class="px-3 py-2 whitespace-nowrap text-xs font-mono">{{ $offer->mcc_mnc ?? '—' }}</td>
                                <td class="px-3 py-2 whitespace-nowrap">{{ $supplierNames[$offer->supplier_id] ?? '—' }}</td>
                                <td class="px-3 py-2 whitespace-nowrap">{{ $connectionNames[$offer->supplier_connection_id] ?? '—' }}</td>
                                <td class="px-3 py-2 whitespace-nowrap text-xs font-mono">{{ $connectionUsernames[$offer->supplier_connection_id] ?? '—' }}</td>
                                <td class="px-3 py-2 whitespace-nowrap">{{ $productTypeLabels[$offer->product_type_id] ?? '—' }}</td>
                                <td class="px-3 py-2 whitespace-nowrap">{{ $knownHopsLabels[$offer->known_hops_dropdown_item_id] ?? '—' }}</td>
                                <td class="px-3 py-2 whitespace-nowrap">{{ $senderIdLabels[$offer->sender_id_supported_dropdown_item_id] ?? '—' }}</td>
                                <td class="px-3 py-2 whitespace-nowrap">{{ $offer->charge_type ?? '—' }}</td>
                                <td class="px-3 py-2 whitespace-nowrap">{{ $chargeModelLabels[$offer->charge_model_id] ?? '—' }}</td>
                                <td class="px-3 py-2 text-center">
                                    @if($offer->is_exclusive)
                                        <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 text-xs font-medium">
                                            {{ __('Yes') }}
                                        </span>
                                    @else
                                        <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-gray-100 text-gray-600 text-xs font-medium">
                                            {{ __('No') }}
                                        </span>
                                    @endif
                                </td>
                                <td class="px-3 py-2 text-right whitespace-nowrap">
                                    <a href="{{ route('offers.history', $offer) }}"
                                       target="_blank"
                                       class="text-indigo-600 hover:text-indigo-900 underline decoration-dotted">
                                        {{ number_format((float)$offer->price, 6) }}
                                    </a>
                                </td>
                                <td class="px-3 py-2 text-right whitespace-nowrap">
                                    <a href="{{ route('offers.history', $offer) }}"
                                       target="_blank"
                                       class="text-indigo-600 hover:text-indigo-900 underline decoration-dotted">
                                        {{ optional($offer->effective_date)->format('Y-m-d') ?? '—' }}
                                    </a>
                                </td>
                                <td class="px-3 py-2 text-right whitespace-nowrap text-xs space-x-1">
                                    <a href="{{ route('offers.edit', $offer) }}"
                                       class="inline-flex items-center px-2 py-1 border border-gray-300 rounded-md bg-white text-gray-700 hover:bg-gray-50">
                                        {{ __('Edit') }}
                                    </a>
                                    <form method="POST" action="{{ route('offers.destroy', $offer) }}" class="inline-block"
                                          onsubmit="return confirm('{{ __('Delete this offer?') }}');">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit"
                                                class="inline-flex items-center px-2 py-1 border border-red-300 rounded-md bg-white text-red-600 hover:bg-red-50">
                                            {{ __('Delete') }}
                                        </button>
                                    </form>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="16" class="px-3 py-6 text-center text-sm text-gray-500">
                                    {{ __('No offers found.') }}
                                </td>
                            </tr>
                        @endforelse
                        </tbody>
                    </table>
                </div>

                <div class="mt-4 flex flex-col gap-4">
                    <div class="flex items-center justify-between">
                        <div class="text-xs text-gray-500">
                            {{ __('Select offers and click "Mass Update" to adjust common attributes.') }}
                        </div>
                        <button type="button"
                                id="show_bulk_update_panel"
                                class="inline-flex items-center px-3 py-1.5 border border-gray-300 rounded-md bg-white text-sm text-gray-700 hover:bg-gray-50">
                            {{ __('Mass Update') }}
                        </button>
                    </div>

                    <div id="bulk_update_panel" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3 text-sm hidden">
                        <div class="flex flex-col">
                            <label for="bulk_known_hops_dropdown_item_id" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                                {{ __('Known Hops') }}
                            </label>
                            <select id="bulk_known_hops_dropdown_item_id" name="bulk_known_hops_dropdown_item_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('No change') }}</option>
                                @foreach($knownHopsOptions as $item)
                                    <option value="{{ $item->id }}">{{ $item->label }}</option>
                                @endforeach
                            </select>
                        </div>

                        <div class="flex flex-col">
                            <label for="bulk_sender_id_supported_dropdown_item_id" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                                {{ __('Sender Id Supported') }}
                            </label>
                            <select id="bulk_sender_id_supported_dropdown_item_id" name="bulk_sender_id_supported_dropdown_item_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('No change') }}</option>
                                @foreach($senderIdOptions as $item)
                                    <option value="{{ $item->id }}">{{ $item->label }}</option>
                                @endforeach
                            </select>
                        </div>

                        <div class="flex flex-col">
                            <label for="bulk_charge_model_id" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                                {{ __('Charge Model') }}
                            </label>
                            <select id="bulk_charge_model_id" name="bulk_charge_model_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('No change') }}</option>
                                @foreach($chargeModelOptions as $item)
                                    <option value="{{ $item->id }}">{{ $item->name }}</option>
                                @endforeach
                            </select>
                        </div>

                        <div class="flex flex-col">
                            <label for="bulk_is_exclusive" class="font-medium text-gray-700 text-xs uppercase tracking-wide">
                                {{ __('Is Exclusive') }}
                            </label>
                            <select id="bulk_is_exclusive" name="bulk_is_exclusive" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                <option value="">{{ __('No change') }}</option>
                                <option value="1">{{ __('Yes') }}</option>
                                <option value="0">{{ __('No') }}</option>
                            </select>
                        </div>

                        <div class="md:col-span-2 lg:col-span-4 flex justify-end pt-1">
                            <button type="submit"
                                    class="inline-flex items-center px-4 py-1.5 border border-transparent rounded-md bg-indigo-600 text-white text-sm hover:bg-indigo-700">
                                {{ __('Apply bulk changes') }}
                            </button>
                        </div>
                    </div>
                </div>

                <div class="mt-4">
                    {{ $offers->links() }}
                </div>
            </form>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const selectAll = document.getElementById('select_all_offers');
            const bulkButton = document.getElementById('show_bulk_update_panel');
            const bulkPanel = document.getElementById('bulk_update_panel');
            const checkboxes = Array.from(document.querySelectorAll('.offer-select'));

            if (selectAll) {
                selectAll.addEventListener('change', function () {
                    checkboxes.forEach(cb => {
                        cb.checked = selectAll.checked;
                    });
                });
            }

            if (bulkButton && bulkPanel) {
                bulkButton.addEventListener('click', function () {
                    const anyChecked = checkboxes.some(cb => cb.checked);
                    if (!anyChecked) {
                        alert('Please select at least one offer to mass update.');
                        return;
                    }
                    bulkPanel.classList.remove('hidden');
                    bulkPanel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
                });
            }
        });
    </script>
</x-app-layout>
