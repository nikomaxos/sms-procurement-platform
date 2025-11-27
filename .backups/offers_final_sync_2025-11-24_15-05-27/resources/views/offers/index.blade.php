<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ __('Offers') }}
        </h2>
    </x-slot>

    @php
        // Guard collections so missing vars don't explode the view
        $countries        = $countries        ?? collect();
        $suppliers        = $suppliers        ?? collect();
        $networks         = $networks         ?? collect();
        $connections      = $connections      ?? collect();
        $productTypeItems = $productTypeItems ?? collect();
        $knownHopsItems   = $knownHopsItems   ?? collect();
        $senderIdItems    = $senderIdItems    ?? collect();
        $offers           = $offers           ?? collect();
        $filters          = $filters          ?? [];

        // Pre-build networks array for JS
        $networksForJs = $networks->map(function ($n) {
            return [
                'id'         => $n->id,
                'name'       => $n->name,
                'country_id' => $n->country_id,
            ];
        })->values();
    @endphp

    <div class="py-6">
        <div class="mx-auto w-11/12 max-w-7xl sm:px-4 lg:px-6">
            <div class="bg-white shadow-sm sm:rounded-lg">
                {{-- Filters --}}
                <div class="px-4 py-4 border-b border-gray-200">
                    <form method="GET" action="{{ route('offers.index') }}" id="offers-filters-form">
                        <div class="flex flex-wrap gap-3">
                            {{-- Country --}}
                            <div class="w-full md:w-1/5">
                                <label for="filter_country_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('Country') }}
                                </label>
                                <select
                                    name="country_id"
                                    id="filter_country_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('All countries') }}</option>
                                    @foreach ($countries as $country)
                                        <option value="{{ $country->id }}" @selected(($filters['country_id'] ?? '') == $country->id)>
                                            {{ $country->name }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- Network (filtered via JS by country) --}}
                            <div class="w-full md:w-1/5">
                                <label for="filter_network_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('Network') }}
                                </label>
                                <select
                                    name="network_id"
                                    id="filter_network_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('All networks') }}</option>
                                    {{-- Options will be filled via JS, based on selected country --}}
                                </select>
                            </div>

                            {{-- Supplier --}}
                            <div class="w-full md:w-1/5">
                                <label for="filter_supplier_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('Supplier') }}
                                </label>
                                <select
                                    name="supplier_id"
                                    id="filter_supplier_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('All suppliers') }}</option>
                                    @foreach ($suppliers as $supplier)
                                        <option value="{{ $supplier->id }}" @selected(($filters['supplier_id'] ?? '') == $supplier->id)>
                                            {{ $supplier->name }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- Product type --}}
                            <div class="w-full md:w-1/5">
                                <label for="filter_product_type" class="block text-xs font-medium text-gray-700">
                                    {{ __('Product type') }}
                                </label>
                                <select
                                    name="product_type_id"
                                    id="filter_product_type"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('All') }}</option>
                                    @foreach ($productTypeItems as $item)
                                        <option value="{{ $item->id }}" @selected(($filters['product_type_id'] ?? '') == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- Charge type --}}
                            <div class="w-full md:w-1/5">
                                <label for="filter_charge_type" class="block text-xs font-medium text-gray-700">
                                    {{ __('Charge type') }}
                                </label>
                                <select
                                    name="charge_type"
                                    id="filter_charge_type"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('All') }}</option>
                                    <option value="per_submit" @selected(($filters['charge_type'] ?? '') === 'per_submit')>
                                        {{ __('Per Submit') }}
                                    </option>
                                    <option value="per_delivered" @selected(($filters['charge_type'] ?? '') === 'per_delivered')>
                                        {{ __('Per Delivered') }}
                                    </option>
                                </select>
                            </div>

                            {{-- Known hops --}}
                            <div class="w-full md:w-1/5">
                                <label for="filter_known_hops" class="block text-xs font-medium text-gray-700">
                                    {{ __('Known hops') }}
                                </label>
                                <select
                                    name="known_hops_dropdown_item_id"
                                    id="filter_known_hops"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('All') }}</option>
                                    @foreach ($knownHopsItems as $item)
                                        <option value="{{ $item->id }}" @selected(($filters['known_hops_dropdown_item_id'] ?? '') == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- Sender ID supported --}}
                            <div class="w-full md:w-1/5">
                                <label for="filter_sender_id" class="block text-xs font-medium text-gray-700">
                                    {{ __('Sender ID supported') }}
                                </label>
                                <select
                                    name="sender_id_supported_dropdown_item_id"
                                    id="filter_sender_id"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('All') }}</option>
                                    @foreach ($senderIdItems as $item)
                                        <option value="{{ $item->id }}" @selected(($filters['sender_id_supported_dropdown_item_id'] ?? '') == $item->id)>
                                            {{ $item->label }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            {{-- Exclusive --}}
                            <div class="w-full md:w-1/5">
                                <label for="filter_is_exclusive" class="block text-xs font-medium text-gray-700">
                                    {{ __('Exclusive') }}
                                </label>
                                <select
                                    name="is_exclusive"
                                    id="filter_is_exclusive"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="">{{ __('All') }}</option>
                                    <option value="1" @selected(($filters['is_exclusive'] ?? '') === '1')>{{ __('Yes') }}</option>
                                    <option value="0" @selected(($filters['is_exclusive'] ?? '') === '0')>{{ __('No') }}</option>
                                </select>
                            </div>

                            {{-- Per-page --}}
                            <div class="w-full md:w-1/5">
                                <label for="filter_per_page" class="block text-xs font-medium text-gray-700">
                                    {{ __('Per page') }}
                                </label>
                                <select
                                    name="per_page"
                                    id="filter_per_page"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    @foreach ([25, 50, 100, 200] as $size)
                                        <option value="{{ $size }}" @selected(($filters['per_page'] ?? 25) == $size)>
                                            {{ $size }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>
                        </div>

                        <div class="mt-4 flex flex-wrap items-center justify-between gap-3">
                            <div class="text-xs text-gray-500">
                                {{ __('Use the filters above to narrow down offers.') }}
                            </div>
                            <div class="flex items-center gap-2">
                                <a
                                    href="{{ route('offers.index') }}"
                                    class="inline-flex items-center px-3 py-1.5 border border-gray-300 rounded-md text-xs font-medium text-gray-700 bg-white hover:bg-gray-50"
                                >
                                    {{ __('Reset') }}
                                </a>
                                <button
                                    type="submit"
                                    class="inline-flex items-center px-3 py-1.5 border border-transparent rounded-md text-xs font-medium text-white bg-indigo-600 hover:bg-indigo-700"
                                >
                                    {{ __('Apply filters') }}
                                </button>
                            </div>
                        </div>
                    </form>
                </div>

                {{-- Table + Mass update --}}
                <div class="px-4 pt-4 pb-5">
                    <div class="flex items-center justify-between mb-3">
                        <div class="text-sm text-gray-600">
                            @php
                                $totalOffers = $offers instanceof \Illuminate\Pagination\LengthAwarePaginator
                                    ? $offers->total()
                                    : $offers->count();
                            @endphp
                            {{ __('Found :count offers', ['count' => $totalOffers]) }}
                        </div>
                        <a
                            href="{{ route('offers.create') }}"
                            class="inline-flex items-center px-3 py-2 bg-indigo-600 text-white text-xs font-semibold rounded-md hover:bg-indigo-700"
                        >
                            {{ __('+ New Offer') }}
                        </a>
                    </div>

                    <form method="POST" action="{{ route('offers.bulk_update') }}" id="offers-mass-update-form">
                        @csrf

                        <div class="overflow-x-auto">
                            <table class="min-w-full text-xs">
                                <thead>
                                    <tr class="border-b border-gray-200 bg-gray-50 text-[11px] uppercase tracking-wide text-gray-600">
                                        <th class="px-2 py-2 text-left">
                                            <input type="checkbox" id="select_all_offers" class="rounded border-gray-300">
                                        </th>
                                        <th class="px-2 py-2 text-left">{{ __('Country') }}</th>
                                        <th class="px-2 py-2 text-left">{{ __('Network') }}</th>
                                        <th class="px-2 py-2 text-left">{{ __('MCC/MNC') }}</th>
                                        <th class="px-2 py-2 text-left">{{ __('Supplier') }}</th>
                                        <th class="px-2 py-2 text-left">{{ __('Connection') }}</th>
                                        <th class="px-2 py-2 text-right">{{ __('Price') }}</th>
                                        <th class="px-2 py-2 text-left">{{ __('Charge type') }}</th>
                                        <th class="px-2 py-2 text-left">{{ __('Product type') }}</th>
                                        <th class="px-2 py-2 text-left">{{ __('Known hops') }}</th>
                                        <th class="px-2 py-2 text-left">{{ __('Sender ID supported') }}</th>
                                        <th class="px-2 py-2 text-center">{{ __('Exclusive') }}</th>
                                        <th class="px-2 py-2 text-left">{{ __('Effective date') }}</th>
                                        <th class="px-2 py-2 text-left">{{ __('Updated at') }}</th>
                                        <th class="px-2 py-2 text-right">{{ __('Actions') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($offers as $offer)
                                        <tr class="border-b border-gray-100 hover:bg-gray-50">
                                            <td class="px-2 py-1 align-top">
                                                <input
                                                    type="checkbox"
                                                    name="offer_ids[]"
                                                    value="{{ $offer->id }}"
                                                    class="offer-checkbox rounded border-gray-300"
                                                >
                                            </td>
                                            <td class="px-2 py-1 align-top">
                                                {{ $offer->country_name ?? $offer->country->name ?? '' }}
                                            </td>
                                            <td class="px-2 py-1 align-top">
                                                {{ $offer->network_name ?? $offer->network->name ?? '' }}
                                            </td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">
                                                {{ $offer->mcc_mnc ?? trim(($offer->mcc ?? '') . ($offer->mnc ?? '')) }}
                                            </td>
                                            <td class="px-2 py-1 align-top">
                                                {{ $offer->supplier_name ?? $offer->supplier->name ?? '' }}
                                            </td>
                                            <td class="px-2 py-1 align-top">
                                                {{ $offer->connection_name ?? $offer->supplierConnection->name ?? '' }}
                                            </td>
                                            <td class="px-2 py-1 align-top text-right whitespace-nowrap">
                                                {{ number_format($offer->price, 6) }}
                                            </td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">
                                                @if ($offer->charge_type === 'per_submit')
                                                    {{ __('Per Submit') }}
                                                @elseif ($offer->charge_type === 'per_delivered')
                                                    {{ __('Per Delivered') }}
                                                @else
                                                    {{ $offer->charge_type }}
                                                @endif
                                            </td>
                                            <td class="px-2 py-1 align-top">
                                                {{ $offer->productType->label ?? '' }}
                                            </td>
                                            <td class="px-2 py-1 align-top">
                                                {{ $offer->knownHopsItem->label ?? '' }}
                                            </td>
                                            <td class="px-2 py-1 align-top">
                                                {{ $offer->senderIdSupportedItem->label ?? '' }}
                                            </td>
                                            <td class="px-2 py-1 align-top text-center">
                                                @if ($offer->is_exclusive)
                                                    <span class="inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-[10px] font-medium text-green-800">
                                                        {{ __('Yes') }}
                                                    </span>
                                                @else
                                                    <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-[10px] font-medium text-gray-600">
                                                        {{ __('No') }}
                                                    </span>
                                                @endif
                                            </td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">
                                                {{ optional($offer->effective_date)->format('Y-m-d') }}
                                            </td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">
                                                {{ optional($offer->updated_at)->format('Y-m-d H:i') }}
                                            </td>
                                            <td class="px-2 py-1 align-top text-right whitespace-nowrap">
                                                <a
                                                    href="{{ route('offers.edit', $offer) }}"
                                                    class="inline-flex items-center px-2 py-1 border border-gray-300 rounded-md text-[11px] text-gray-700 hover:bg-gray-50 mr-1"
                                                >
                                                    {{ __('Edit') }}
                                                </a>

                                                <form
                                                    method="POST"
                                                    action="{{ route('offers.destroy', $offer) }}"
                                                    class="inline"
                                                    onsubmit="return confirm('{{ __('Are you sure you want to delete this offer?') }}');"
                                                >
                                                    @csrf
                                                    @method('DELETE')
                                                    <button
                                                        type="submit"
                                                        class="inline-flex items-center px-2 py-1 border border-red-300 rounded-md text-[11px] text-red-600 hover:bg-red-50"
                                                    >
                                                        {{ __('Delete') }}
                                                    </button>
                                                </form>
                                            </td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="15" class="px-2 py-4 text-center text-sm text-gray-500">
                                                {{ __('No offers found.') }}
                                            </td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>

                        {{-- Mass update row --}}
                        <div class="mt-4 border-t border-gray-200 pt-3">
                            <div class="flex items-center justify-between mb-2">
                                <div class="text-sm font-semibold text-gray-700">
                                    {{ __('Mass Update Selected Offers') }}
                                </div>
                                <button
                                    type="button"
                                    id="toggle-mass-update"
                                    class="inline-flex items-center px-3 py-1.5 border border-gray-300 rounded-md text-xs font-medium text-gray-700 bg-white hover:bg-gray-50"
                                >
                                    {{ __('Mass Update') }}
                                </button>
                            </div>

                            <div id="mass-update-panel" class="hidden">
                                <div class="flex flex-nowrap gap-3 overflow-x-auto pb-2">
                                    {{-- Product type --}}
                                    <div class="w-48 flex-shrink-0">
                                        <label class="block text-xs font-medium text-gray-700">
                                            {{ __('Product type') }}
                                        </label>
                                        <select
                                            name="mass_product_type_id"
                                            class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                        >
                                            <option value="">{{ __('(no change)') }}</option>
                                            @foreach ($productTypeItems as $item)
                                                <option value="{{ $item->id }}">{{ $item->label }}</option>
                                            @endforeach
                                        </select>
                                    </div>

                                    {{-- Known hops --}}
                                    <div class="w-48 flex-shrink-0">
                                        <label class="block text-xs font-medium text-gray-700">
                                            {{ __('Known hops') }}
                                        </label>
                                        <select
                                            name="mass_known_hops_dropdown_item_id"
                                            class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                        >
                                            <option value="">{{ __('(no change)') }}</option>
                                            @foreach ($knownHopsItems as $item)
                                                <option value="{{ $item->id }}">{{ $item->label }}</option>
                                            @endforeach
                                        </select>
                                    </div>

                                    {{-- Sender ID supported --}}
                                    <div class="w-48 flex-shrink-0">
                                        <label class="block text-xs font-medium text-gray-700">
                                            {{ __('Sender ID supported') }}
                                        </label>
                                        <select
                                            name="mass_sender_id_supported_dropdown_item_id"
                                            class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                        >
                                            <option value="">{{ __('(no change)') }}</option>
                                            @foreach ($senderIdItems as $item)
                                                <option value="{{ $item->id }}">{{ $item->label }}</option>
                                            @endforeach
                                        </select>
                                    </div>

                                    {{-- Charge type --}}
                                    <div class="w-40 flex-shrink-0">
                                        <label class="block text-xs font-medium text-gray-700">
                                            {{ __('Charge type') }}
                                        </label>
                                        <select
                                            name="mass_charge_type"
                                            class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                        >
                                            <option value="">{{ __('(no change)') }}</option>
                                            <option value="per_submit">{{ __('Per Submit') }}</option>
                                            <option value="per_delivered">{{ __('Per Delivered') }}</option>
                                        </select>
                                    </div>

                                    {{-- Exclusive --}}
                                    <div class="w-32 flex-shrink-0">
                                        <label class="block text-xs font-medium text-gray-700">
                                            {{ __('Exclusive') }}
                                        </label>
                                        <select
                                            name="mass_is_exclusive"
                                            class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                        >
                                            <option value="">{{ __('(no change)') }}</option>
                                            <option value="1">{{ __('Yes') }}</option>
                                            <option value="0">{{ __('No') }}</option>
                                        </select>
                                    </div>

                                    {{-- Price --}}
                                    <div class="w-40 flex-shrink-0">
                                        <label class="block text-xs font-medium text-gray-700">
                                            {{ __('Price (0.xxxxxx)') }}
                                        </label>
                                        <input
                                            type="number"
                                            step="0.000001"
                                            min="0"
                                            max="0.999999"
                                            name="mass_price"
                                            class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                                            placeholder="0.012345"
                                        >
                                    </div>
                                </div>

                                <div class="mt-3 flex items-center justify-between">
                                    <p class="text-[11px] text-gray-500">
                                        {{ __('Only fields with a value will be applied to the selected offers.') }}
                                    </p>
                                    <button
                                        type="submit"
                                        class="inline-flex items-center px-3 py-2 bg-indigo-600 text-white text-xs font-semibold rounded-md hover:bg-indigo-700"
                                        onclick="return confirmMassUpdate();"
                                    >
                                        {{ __('Apply to selected') }}
                                    </button>
                                </div>
                            </div>
                        </div>

                        @if ($offers instanceof \Illuminate\Pagination\LengthAwarePaginator)
                            <div class="mt-4">
                                {{ $offers->withQueryString()->links() }}
                            </div>
                        @endif
                    </form>
                </div>
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            // Select all
            const selectAll = document.getElementById('select_all_offers');
            const checkboxes = Array.from(document.querySelectorAll('.offer-checkbox'));

            if (selectAll) {
                selectAll.addEventListener('change', function () {
                    checkboxes.forEach(cb => {
                        cb.checked = selectAll.checked;
                    });
                });
            }

            // Mass update toggle logic
            const toggleBtn = document.getElementById('toggle-mass-update');
            const massPanel = document.getElementById('mass-update-panel');

            function anyOfferSelected() {
                return checkboxes.some(cb => cb.checked);
            }

            if (toggleBtn && massPanel) {
                toggleBtn.addEventListener('click', function () {
                    if (!anyOfferSelected()) {
                        alert(@json(__('Please select at least one offer first.')));
                        return;
                    }
                    massPanel.classList.remove('hidden');
                    massPanel.scrollIntoView({ behavior: 'smooth', block: 'center' });
                });
            }

            window.confirmMassUpdate = function () {
                if (!anyOfferSelected()) {
                    alert(@json(__('Please select at least one offer first.')));
                    return false;
                }
                return true;
            };

            // Dynamic network filter based on country
            const networks = @json($networksForJs);
            const countrySelect = document.getElementById('filter_country_id');
            const networkSelect = document.getElementById('filter_network_id');
            const currentNetworkId = @json($filters['network_id'] ?? '');

            if (countrySelect && networkSelect) {
                function rebuildNetworkOptions() {
                    const selectedCountry = countrySelect.value || '';

                    // Preserve current selection if possible
                    const preserved = networkSelect.value || currentNetworkId;

                    networkSelect.innerHTML = '';
                    const optAll = document.createElement('option');
                    optAll.value = '';
                    optAll.textContent = '{{ __('All networks') }}';
                    networkSelect.appendChild(optAll);

                    networks.forEach(function (n) {
                        if (!selectedCountry || String(n.country_id) === String(selectedCountry)) {
                            const opt = document.createElement('option');
                            opt.value = n.id;
                            opt.textContent = n.name;
                            if (String(n.id) === String(preserved)) {
                                opt.selected = true;
                            }
                            networkSelect.appendChild(opt);
                        }
                    });
                }

                countrySelect.addEventListener('change', rebuildNetworkOptions);
                rebuildNetworkOptions();
            }
        });
    </script>
</x-app-layout>
