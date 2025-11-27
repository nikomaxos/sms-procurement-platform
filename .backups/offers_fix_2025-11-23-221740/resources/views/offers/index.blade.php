<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">{{ __('Offers') }}</h2>
    </x-slot>

    {{-- Guards: set collections if undefined --}}
    @php
        $countries        = $countries        ?? collect();
        $suppliers        = $suppliers        ?? collect();
        $networks         = $networks         ?? collect();
        $connections      = $connections      ?? collect();
        $productTypeItems = $productTypeItems ?? collect();
        $knownHopsItems   = $knownHopsItems   ?? collect();
        $senderIdItems    = $senderIdItems    ?? collect();
        $chargeModels     = $chargeModels     ?? collect();
        $mncs             = $mncs             ?? collect();
        $offers           = $offers           ?? collect();
    @endphp

    <div class="py-6">
        <div class="w-[90vw] mx-auto px-2 sm:px-4 lg:px-6">
            <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-gray-900">{{ __('Offers') }}</h3>
                <a href="{{ route('offers.create') }}"
                   class="inline-flex items-center px-4 py-2 bg-indigo-600 border border-transparent rounded-md
                          font-semibold text-xs text-white uppercase tracking-widest hover:bg-indigo-700
                          focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                    {{ __('New Offer') }}
                </a>
            </div>

            <form method="GET" action="{{ route('offers.index') }}" class="mb-4">
                <div class="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-6 gap-3">
                    <!-- Country -->
                    <div>
                        <label for="filter_country_id" class="block text-xs font-medium text-gray-700">{{ __('Country') }}</label>
                        <select name="filter_country_id" id="filter_country_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($countries as $country)
                                <option value="{{ $country->id }}" @selected(request('filter_country_id') == $country->id)>{{ $country->name }}</option>
                            @endforeach
                        </select>
                    </div>
                    <!-- Network -->
                    <div>
                        <label for="filter_network_id" class="block text-xs font-medium text-gray-700">{{ __('Network') }}</label>
                        <select name="filter_network_id" id="filter_network_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($networks as $network)
                                <option value="{{ $network->id }}" data-country-id="{{ $network->country_id }}"
                                        @selected(request('filter_network_id') == $network->id)>{{ $network->name }}</option>
                            @endforeach
                        </select>
                    </div>
                    <!-- MCCMNC -->
                    <div>
                        <label for="filter_mcc_mnc" class="block text-xs font-medium text-gray-700">{{ __('MCCMNC') }}</label>
                        <input type="text" name="filter_mcc_mnc" id="filter_mcc_mnc"
                               value="{{ request('filter_mcc_mnc') }}" placeholder="20201"
                               class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                    </div>
                    <!-- Supplier -->
                    <div>
                        <label for="filter_supplier_id" class="block text-xs font-medium text-gray-700">{{ __('Supplier') }}</label>
                        <select name="filter_supplier_id" id="filter_supplier_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($suppliers as $supplier)
                                <option value="{{ $supplier->id }}" @selected(request('filter_supplier_id') == $supplier->id)>{{ $supplier->name }}</option>
                            @endforeach
                        </select>
                    </div>
                    <!-- Connection -->
                    <div>
                        <label for="filter_connection_id" class="block text-xs font-medium text-gray-700">{{ __('Connection') }}</label>
                        <select name="filter_connection_id" id="filter_connection_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($connections as $conn)
                                <option value="{{ $conn->id }}" data-supplier-id="{{ $conn->supplier_id }}"
                                        @selected(request('filter_connection_id') == $conn->id)>{{ $conn->name }}</option>
                            @endforeach
                        </select>
                    </div>
                    <!-- Product Type -->
                    <div>
                        <label for="filter_product_type_id" class="block text-xs font-medium text-gray-700">{{ __('Product Type') }}</label>
                        <select name="filter_product_type_id" id="filter_product_type_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($productTypeItems as $item)
                                <option value="{{ $item->id }}" @selected(request('filter_product_type_id') == $item->id)>{{ $item->label }}</option>
                            @endforeach
                        </select>
                    </div>
                    <!-- Known Hops -->
                    <div>
                        <label for="filter_known_hops_id" class="block text-xs font-medium text-gray-700">{{ __('Known Hops') }}</label>
                        <select name="filter_known_hops_id" id="filter_known_hops_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($knownHopsItems as $item)
                                <option value="{{ $item->id }}" @selected(request('filter_known_hops_id') == $item->id)>{{ $item->label }}</option>
                            @endforeach
                        </select>
                    </div>
                    <!-- Sender Id Supported -->
                    <div>
                        <label for="filter_sender_id_supported_id" class="block text-xs font-medium text-gray-700">{{ __('Sender Id Supported') }}</label>
                        <select name="filter_sender_id_supported_id" id="filter_sender_id_supported_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($senderIdItems as $item)
                                <option value="{{ $item->id }}" @selected(request('filter_sender_id_supported_id') == $item->id)>{{ $item->label }}</option>
                            @endforeach
                        </select>
                    </div>
                    <!-- Charge Type -->
                    <div>
                        <label for="filter_charge_type" class="block text-xs font-medium text-gray-700">{{ __('Charge Type') }}</label>
                        <select name="filter_charge_type" id="filter_charge_type"
                                class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            <option value="per_submit" @selected(request('filter_charge_type') == 'per_submit')>{{ __('Per Submit') }}</option>
                            <option value="per_delivered" @selected(request('filter_charge_type') == 'per_delivered')>{{ __('Per Delivered') }}</option>
                        </select>
                    </div>
                    <!-- Charge Model -->
                    <div>
                        <label for="filter_charge_model_id" class="block text-xs font-medium text-gray-700">{{ __('Charge Model') }}</label>
                        <select name="filter_charge_model_id" id="filter_charge_model_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($chargeModels as $model)
                                <option value="{{ $model->id }}" @selected(request('filter_charge_model_id') == $model->id)>{{ $model->name }}</option>
                            @endforeach
                        </select>
                    </div>
                    <!-- Is Exclusive -->
                    <div>
                        <label for="filter_is_exclusive" class="block text-xs font-medium text-gray-700">{{ __('Is Exclusive') }}</label>
                        <select name="filter_is_exclusive" id="filter_is_exclusive"
                                class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                            <option value="">{{ __('All') }}</option>
                            <option value="1" @selected(request('filter_is_exclusive') === '1')>{{ __('Yes') }}</option>
                            <option value="0" @selected(request('filter_is_exclusive') === '0')>{{ __('No') }}</option>
                        </select>
                    </div>
                </div>
                <div class="mt-3 flex items-center justify-between">
                    <div class="flex items-center gap-2">
                        <label for="per_page" class="text-xs font-medium text-gray-700">{{ __('Per page') }}</label>
                        <select id="per_page" name="per_page" class="rounded-md border-gray-300 text-sm">
                            @foreach([25,50,100,200] as $size)
                                <option value="{{ $size }}" @selected((int)request('per_page',50) === $size)>{{ $size }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="flex items-center gap-2">
                        <button type="submit"
                                class="inline-flex items-center px-4 py-2 bg-gray-800 border border-transparent rounded-md text-xs font-semibold text-white uppercase tracking-widest hover:bg-gray-700">
                            {{ __('Apply Filters') }}
                        </button>
                        <a href="{{ route('offers.index') }}"
                           class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-md text-xs font-semibold text-gray-700 bg-white hover:bg-gray-50">
                            {{ __('Reset') }}
                        </a>
                    </div>
                </div>
            </form>

            <form method="POST" action="{{ route('offers.bulk_update') }}">
                @csrf
                <div class="overflow-x-auto bg-white shadow rounded-lg">
                    <table class="min-w-full divide-y divide-gray-200 text-sm">
                        <thead class="bg-gray-50">
                            <tr>
                                <th class="px-3 py-2"><input type="checkbox" id="select_all_offers"
                                                             class="rounded border-gray-300 text-indigo-600 shadow-sm focus:ring-indigo-500"></th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Country') }}</th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Network') }}</th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('MCCMNC') }}</th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Supplier') }}</th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Connection') }}</th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Username') }}</th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Product Type') }}</th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Known Hops') }}</th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Sender Id Supported') }}</th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Charge Type') }}</th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Charge Model') }}</th>
                                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Is Exclusive') }}</th>
                                <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Price') }}</th>
                                <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Effective Date') }}</th>
                                <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">{{ __('Actions') }}</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200 bg-white">
                            @forelse($offers as $offer)
                                <tr class="hover:bg-gray-50">
                                    <td class="px-3 py-2"><input type="checkbox" name="selected_offers[]" value="{{ $offer->id }}" class="offer-row-checkbox rounded border-gray-300 text-indigo-600 shadow-sm focus:ring-indigo-500"></td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap">{{ $offer->country_name ?? '-' }}</td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap">{{ $offer->network_name ?? '-' }}</td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap font-mono">{{ $offer->mcc_mnc ?? '-' }}</td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap">{{ $offer->supplier_name ?? '-' }}</td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap">{{ $offer->connection_name ?? '-' }}</td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap font-mono">{{ $offer->username ?? '-' }}</td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap">{{ $offer->product_type_label ?? '-' }}</td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap">{{ $offer->known_hops_label ?? '-' }}</td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap">{{ $offer->sender_id_supported_label ?? '-' }}</td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap">
                                        @if($offer->charge_type === 'per_delivered')
                                            {{ __('Per Delivered') }}
                                        @elseif($offer->charge_type === 'per_submit')
                                            {{ __('Per Submit') }}
                                        @else
                                            {{ $offer->charge_type ?? '-' }}
                                        @endif
                                    </td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap">{{ $offer->charge_model_name ?? '-' }}</td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap">
                                        @if($offer->is_exclusive)
                                            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">{{ __('Yes') }}</span>
                                        @else
                                            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600">{{ __('No') }}</span>
                                        @endif
                                    </td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap text-right"><a href="{{ route('offers.history', $offer) }}" class="text-indigo-600 hover:text-indigo-900">{{ number_format((float)$offer->price, 6) }}</a></td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap text-right"><a href="{{ route('offers.history', $offer) }}" class="text-indigo-600 hover:text-indigo-900">{{ optional($offer->effective_date)->format('Y-m-d') ?? '-' }}</a></td>
                                    <td class="px-3 py-2 text-xs whitespace-nowrap text-right space-x-1">
                                        <a href="{{ route('offers.edit', $offer) }}"
                                           class="inline-flex items-center px-2 py-1 border border-gray-300 rounded-md bg-white text-gray-700 hover:bg-gray-50">{{ __('Edit') }}</a>
                                        <form action="{{ route('offers.destroy', $offer) }}" method="POST" class="inline-block" onsubmit="return confirm('{{ __('Are you sure you want to delete this offer?') }}');">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit"
                                                    class="inline-flex items-center px-2 py-1 border border-red-300 rounded-md bg-white text-red-700 hover:bg-red-50">{{ __('Delete') }}</button>
                                        </form>
                                    </td>
                                </tr>
                            @empty
                                <tr><td colspan="16" class="px-3 py-4 text-center text-sm text-gray-500">{{ __('No offers found.') }}</td></tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>

                @if($offers instanceof \Illuminate\Pagination\LengthAwarePaginator)
                    <div class="mt-4">{{ $offers->withQueryString()->links() }}</div>
                @endif

                <div id="bulk-section" class="mt-6 border-t border-gray-200 pt-4">
                    <div class="flex items-center justify-between">
                        <p class="text-sm text-gray-600">{{ __('Bulk update selected offers') }}</p>
                        <button type="button" id="bulkToggleButton"
                                class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-semibold rounded-md
                                       text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none
                                       focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed">
                            {{ __('Mass Update') }}
                        </button>
                    </div>
                    <div id="bulkFieldsPanel" class="mt-4 hidden">
                        <div class="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-6 gap-3">
                            <div>
                                <label class="block text-xs font-medium text-gray-700">{{ __('Known Hops') }}</label>
                                <select name="bulk_known_hops_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                    <option value="">{{ __('No change') }}</option>
                                    @foreach($knownHopsItems as $item)
                                        <option value="{{ $item->id }}">{{ $item->label }}</option>
                                    @endforeach
                                </select>
                            </div>
                            <div>
                                <label class="block text-xs font-medium text-gray-700">{{ __('Sender Id Supported') }}</label>
                                <select name="bulk_sender_id_supported_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                    <option value="">{{ __('No change') }}</option>
                                    @foreach($senderIdItems as $item)
                                        <option value="{{ $item->id }}">{{ $item->label }}</option>
                                    @endforeach
                                </select>
                            </div>
                            <div>
                                <label class="block text-xs font-medium text-gray-700">{{ __('Charge Model') }}</label>
                                <select name="bulk_charge_model_id" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                    <option value="">{{ __('No change') }}</option>
                                    @foreach($chargeModels as $model)
                                        <option value="{{ $model->id }}">{{ $model->name }}</option>
                                    @endforeach
                                </select>
                            </div>
                            <div>
                                <label class="block text-xs font-medium text-gray-700">{{ __('Is Exclusive') }}</label>
                                <select name="bulk_is_exclusive" class="mt-1 block w-full rounded-md border-gray-300 text-sm">
                                    <option value="">{{ __('No change') }}</option>
                                    <option value="1">{{ __('Yes') }}</option>
                                    <option value="0">{{ __('No') }}</option>
                                </select>
                            </div>
                        </div>
                        <div class="mt-4 flex justify-end">
                            <button type="submit"
                                    class="inline-flex items-center px-4 py-2 bg-green-600 border border-transparent rounded-md
                                           font-semibold text-xs text-white uppercase tracking-widest hover:bg-green-700
                                           focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500">
                                {{ __('Apply Bulk Changes') }}
                            </button>
                        </div>
                    </div>
                </div>
            </form>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            // Dynamic country→network filter
            const countrySelect = document.getElementById('filter_country_id');
            const networkSelect = document.getElementById('filter_network_id');
            if (countrySelect && networkSelect) {
                const netOpts = Array.from(networkSelect.options);
                function updateNetworks() {
                    const cid = countrySelect.value || '';
                    const curVal = networkSelect.value;
                    let valid = false;
                    netOpts.forEach(opt => {
                        if (!opt.value) { opt.hidden = false; opt.disabled = false; return; }
                        const ocid = opt.dataset.countryId || '';
                        const show = !cid || ocid === cid;
                        opt.hidden = !show;
                        opt.disabled = !show;
                        if (show && opt.value === curVal) valid = true;
                    });
                    if (!valid) networkSelect.value = '';
                }
                countrySelect.addEventListener('change', updateNetworks);
                updateNetworks();
            }

            // Mass Update panel logic
            const selectAll = document.getElementById('select_all_offers');
            const rowChecks = Array.from(document.querySelectorAll('.offer-row-checkbox'));
            const bulkBtn = document.getElementById('bulkToggleButton');
            const bulkPanel = document.getElementById('bulkFieldsPanel');
            function updateBulkButton() {
                const any = rowChecks.some(cb => cb.checked);
                bulkBtn.disabled = !any;
                if (!any) bulkPanel.classList.add('hidden');
            }
            if (selectAll) {
                selectAll.addEventListener('change', () => {
                    rowChecks.forEach(cb => cb.checked = selectAll.checked);
                    updateBulkButton();
                });
            }
            rowChecks.forEach(cb => cb.addEventListener('change', updateBulkButton));
            if (bulkBtn && bulkPanel) {
                bulkBtn.addEventListener('click', function () {
                    if (!bulkBtn.disabled) bulkPanel.classList.toggle('hidden');
                });
            }
            updateBulkButton();
        });
    </script>
</x-app-layout>
