<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ __('Offers') }}
        </h2>
    </x-slot>

    <style>
        .offers-page-container { width: 90vw; margin: 0 auto; }
        .offers-filter-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 0.75rem; }
    </style>

    @php
        $perPage = (int) request('per_page', 50);
        $page = max((int) request('page', 1), 1);

        // Filters data from DB (no dependency on controller variables)
        $countries = DB::table('countries')->orderBy('name')->get();
        $suppliers = DB::table('suppliers')->orderBy('name')->get();
        $networks  = DB::table('networks')->orderBy('name')->get();
        $connections = DB::table('supplier_connections')->orderBy('name')->get();

        $productTypeItems = DB::table('dropdown_items')
            ->where('dropdown_menu_id', 1)
            ->orderBy('label')
            ->get();

        $knownHopsItems = DB::table('dropdown_items')
            ->where('dropdown_menu_id', 2)
            ->orderBy('label')
            ->get();

        $senderIdItems = DB::table('dropdown_items')
            ->where('dropdown_menu_id', 3)
            ->orderBy('label')
            ->get();


            ->select('id', 'name')
            ->orderBy('name')
            ->get();

        // Base query with joins so we can show readable labels
        $query = DB::table('supplier_offers as so')
            ->leftJoin('countries as c', 'c.id', '=', 'so.country_id')
            ->leftJoin('networks as n', 'n.id', '=', 'so.network_id')
            ->leftJoin('suppliers as s', 's.id', '=', 'so.supplier_id')
            ->leftJoin('supplier_connections as sc', 'sc.id', '=', 'so.supplier_connection_id')
            ->leftJoin('dropdown_items as pt', 'pt.id', '=', 'so.product_type_id')
            ->leftJoin('dropdown_items as kh', 'kh.id', '=', 'so.known_hops_dropdown_item_id')
            ->leftJoin('dropdown_items as si', 'si.id', '=', 'so.sender_id_supported_dropdown_item_id')
            ->leftJoin('charge_models as cm', 'cm.id', '=', 'so.charge_model_id')
            ->selectRaw('
                so.*,
                c.name  as country_name,
                n.name  as network_name,
                s.name  as supplier_name,
                sc.name as connection_name,
                sc.username as connection_username,
                pt.label as product_type_label,
                kh.label as known_hops_label,
                si.label as sender_id_supported_label,
                cm.name  as charge_model_name
            ');

        // Apply filters from request
        if ($cid = request('filter_country_id')) {
            $query->where('so.country_id', $cid);
        }
        if ($nid = request('filter_network_id')) {
            $query->where('so.network_id', $nid);
        }
        if ($mccmnc = trim(request('filter_mcc_mnc', ''))) {
            $query->where('so.mcc_mnc', 'like', $mccmnc.'%');
        }
        if ($sid = request('filter_supplier_id')) {
            $query->where('so.supplier_id', $sid);
        }
        if ($conn = request('filter_connection_id')) {
            $query->where('so.supplier_connection_id', $conn);
        }
        if ($pt = request('filter_product_type_id')) {
            $query->where('so.product_type_id', $pt);
        }
        if ($kh = request('filter_known_hops_id')) {
            $query->where('so.known_hops_dropdown_item_id', $kh);
        }
        if ($si = request('filter_sender_id_supported_id')) {
            $query->where('so.sender_id_supported_dropdown_item_id', $si);
        }
        if (($ct = request('filter_charge_type')) !== null && $ct !== '') {
            $query->where('so.charge_type', $ct);
        }
        if ($cm = request('filter_charge_model_id')) {
            $query->where('so.charge_model_id', $cm);
        }
        if (($iex = request('filter_is_exclusive')) !== null && $iex !== '') {
            $query->where('so.is_exclusive', (int) $iex);
        }

        $total = $query->count();
        $rows = $query
            ->orderBy('c.name')
            ->orderBy('n.name')
            ->orderBy('s.name')
            ->forPage($page, $perPage)
            ->get();

        $offers = new \Illuminate\Pagination\LengthAwarePaginator(
            $rows,
            $total,
            $perPage,
            $page,
            ['path' => request()->url(), 'query' => request()->query()]
        );
    @endphp

    <div class="py-6 offers-page-container">
        <!-- widen page: use full width with padding -->
        <div class="mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-gray-900">
                    {{ __('Offers') }}
                </h3>

                <a href="{{ route('offers.create') }}"
                   class="inline-flex items-center px-4 py-2 bg-indigo-600 border border-transparent rounded-md
                          font-semibold text-xs text-white uppercase tracking-widest hover:bg-indigo-700
                          focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                    {{ __('New Offer') }}
                </a>
            </div>

            {{-- Filters --}}
            <form method="GET" action="{{ route('offers.index') }}" class="mb-4">
                <!-- Make filters compact & multi-column: up to 4–6 per row -->
                <div class="offers-filter-grid">
                    {{-- Country --}}
                    <div>
                        <label for="filter_country_id" class="block text-xs font-medium text-gray-700">
                            {{ __('Country') }}
                        </label>
                        <select name="filter_country_id" id="filter_country_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($countries as $country)
                                <option value="{{ $country->id }}"
                                        @selected(request('filter_country_id') == $country->id)>
                                    {{ $country->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- Network --}}
                    <div>
                        <label for="filter_network_id" class="block text-xs font-medium text-gray-700">
                            {{ __('Network') }}
                        </label>
                        <select name="filter_network_id" id="filter_network_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($networks as $network)
                                <option value="{{ $network->id }}"
                                        data-country-id="{{ $network->country_id ?? '' }}"
                                        @selected(request('filter_network_id') == $network->id)>
                                    {{ $network->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- MCCMNC --}}
                    <div>
                        <label for="filter_mcc_mnc" class="block text-xs font-medium text-gray-700">
                            {{ __('MCCMNC') }}
                        </label>
                        <input type="text" name="filter_mcc_mnc" id="filter_mcc_mnc"
                               value="{{ request('filter_mcc_mnc') }}"
                               placeholder="20201"
                               class="mt-1 block w-full rounded-md border-gray-300 text-xs" />
                    </div>

                    {{-- Supplier --}}
                    <div>
                        <label for="filter_supplier_id" class="block text-xs font-medium text-gray-700">
                            {{ __('Supplier') }}
                        </label>
                        <select name="filter_supplier_id" id="filter_supplier_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($suppliers as $supplier)
                                <option value="{{ $supplier->id }}"
                                        @selected(request('filter_supplier_id') == $supplier->id)>
                                    {{ $supplier->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- Connection --}}
                    <div>
                        <label for="filter_connection_id" class="block text-xs font-medium text-gray-700">
                            {{ __('Connection') }}
                        </label>
                        <select name="filter_connection_id" id="filter_connection_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($connections as $conn)
                                <option value="{{ $conn->id }}"
                                        data-supplier-id="{{ $conn->supplier_id ?? '' }}"
                                        @selected(request('filter_connection_id') == $conn->id)>
                                    {{ $conn->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- Product Type --}}
                    <div>
                        <label for="filter_product_type_id" class="block text-xs font-medium text-gray-700">
                            {{ __('Product Type') }}
                        </label>
                        <select name="filter_product_type_id" id="filter_product_type_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($productTypeItems as $item)
                                <option value="{{ $item->id }}"
                                        @selected(request('filter_product_type_id') == $item->id)>
                                    {{ $item->label }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- Known Hops --}}
                    <div>
                        <label for="filter_known_hops_id" class="block text-xs font-medium text-gray-700">
                            {{ __('Known Hops') }}
                        </label>
                        <select name="filter_known_hops_id" id="filter_known_hops_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($knownHopsItems as $item)
                                <option value="{{ $item->id }}"
                                        @selected(request('filter_known_hops_id') == $item->id)>
                                    {{ $item->label }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- Sender Id Supported --}}
                    <div>
                        <label for="filter_sender_id_supported_id" class="block text-xs font-medium text-gray-700">
                            {{ __('Sender Id Supported') }}
                        </label>
                        <select name="filter_sender_id_supported_id" id="filter_sender_id_supported_id"
                                class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                            <option value="">{{ __('All') }}</option>
                            @foreach ($senderIdItems as $item)
                                <option value="{{ $item->id }}"
                                        @selected(request('filter_sender_id_supported_id') == $item->id)>
                                    {{ $item->label }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- Charge Type --}}
                    <div>
                        <label for="filter_charge_type" class="block text-xs font-medium text-gray-700">
                            {{ __('Charge Type') }}
                        </label>
                        <select name="filter_charge_type" id="filter_charge_type"
                                class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                            <option value="">{{ __('All') }}</option>
                            <option value="per_submit" @selected(request('filter_charge_type') === 'per_submit')>
                                {{ __('Per Submit') }}
                            </option>
                            <option value="per_delivered" @selected(request('filter_charge_type') === 'per_delivered')>
                                {{ __('Per Delivered') }}
                            </option>
                        </select>
                    </div>

                    {{--  --}}

                    {{-- Is Exclusive --}}
                    <div>
                        <label for="filter_is_exclusive" class="block text-xs font-medium text-gray-700">
                            {{ __('Is Exclusive') }}
                        </label>
                        <select name="filter_is_exclusive" id="filter_is_exclusive"
                                class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                            <option value="">{{ __('All') }}</option>
                            <option value="1" @selected(request('filter_is_exclusive') === '1')>{{ __('Yes') }}</option>
                            <option value="0" @selected(request('filter_is_exclusive') === '0')>{{ __('No') }}</option>
                        </select>
                    </div>
                </div>

                <div class="mt-3 flex items-center justify-between">
                    <div class="flex items-center gap-2">
                        <label for="per_page" class="text-xs font-medium text-gray-700">
                            {{ __('Per page') }}
                        </label>
                        <select id="per_page" name="per_page"
                                class="rounded-md border-gray-300 text-xs">
                            @foreach ([25, 50, 100, 200] as $size)
                                <option value="{{ $size }}"
                                        @selected((int) request('per_page', 50) === $size)>
                                    {{ $size }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <div class="flex items-center gap-2">
                        <button type="submit"
                                class="inline-flex items-center px-4 py-2 bg-gray-800 border border-transparent rounded-md
                                       text-xs font-semibold text-white uppercase tracking-widest hover:bg-gray-700">
                            {{ __('Apply Filters') }}
                        </button>
                        <a href="{{ route('offers.index') }}"
                           class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-md
                                  text-xs font-semibold text-gray-700 bg-white hover:bg-gray-50">
                            {{ __('Reset') }}
                        </a>
                    </div>
                </div>
            </form>

            {{-- Table + Bulk update --}}
            <form method="POST" action="{{ route('offers.bulk_update') }}">
                @csrf
                <div class="overflow-x-auto bg-white shadow rounded-lg">
                    <table class="min-w-full divide-y divide-gray-200 text-xs">
                        <thead class="bg-gray-50">
                            <tr>
                                <th class="px-2 py-2">
                                    <input type="checkbox" id="select_all_offers"
                                           class="rounded border-gray-300 text-indigo-600 shadow-sm focus:ring-indigo-500" />
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Country') }}
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Network') }}
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('MCCMNC') }}
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Supplier') }}
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Connection') }}
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Username') }}
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Product Type') }}
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Known Hops') }}
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Sender Id Supported') }}
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Charge Type') }}
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('') }}
                                </th>
                                <th class="px-2 py-2 text-left font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Is Exclusive') }}
                                </th>
                                <th class="px-2 py-2 text-right font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Price') }}
                                </th>
                                <th class="px-2 py-2 text-right font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Effective Date') }}
                                </th>
                                <th class="px-2 py-2 text-right font-medium text-gray-500 uppercase tracking-wider">
                                    {{ __('Actions') }}
                                </th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200 bg-white">
                            @forelse ($offers as $offer)
                                <tr class="hover:bg-gray-50">
                                    
                                    <td class="px-2 py-2 whitespace-nowrap">
                                        @if ($offer->is_exclusive)
                                            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                                {{ __('Yes') }}
                                            </span>
                                        @else
                                            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600">
                                                {{ __('No') }}
                                            </span>
                                        @endif
                                    </td>
                                    <td class="px-2 py-2 whitespace-nowrap text-right">
                                        <a href="{{ route('offers.history', $offer->id) }}"
                                           class="text-indigo-600 hover:text-indigo-900">
                                            {{ number_format((float) $offer->price, 6) }}
                                        </a>
                                    </td>
                                    <td class="px-2 py-2 whitespace-nowrap text-right">
                                        <a href="{{ route('offers.history', $offer->id) }}"
                                           class="text-indigo-600 hover:text-indigo-900">
                                            {{ $offer->effective_date ? \Carbon\Carbon::parse($offer->effective_date)->format('Y-m-d') : '-' }}
                                        </a>
                                    </td>
                                    <td class="px-2 py-2 whitespace-nowrap text-right space-x-1">
                                        <a href="{{ route('offers.edit', $offer->id) }}"
                                           class="inline-flex items-center px-2 py-1 border border-gray-300 rounded-md bg-white text-gray-700 hover:bg-gray-50">
                                            {{ __('Edit') }}
                                        </a>
                                        <form action="{{ route('offers.destroy', $offer->id) }}"
                                              method="POST"
                                              class="inline-block"
                                              onsubmit="return confirm('Are you sure you want to delete this offer?');">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit"
                                                    class="inline-flex items-center px-2 py-1 border border-red-300 rounded-md bg-white text-red-700 hover:bg-red-50">
                                                {{ __('Delete') }}
                                            </button>
                                        </form>
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="16" class="px-3 py-4 text-center text-sm text-gray-500">
                                        {{ __('No offers found.') }}
                                    </td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>

                {{-- Pagination --}}
                @if ($offers instanceof \Illuminate\Pagination\LengthAwarePaginator)
                    <div class="mt-4">
                        {{ $offers->withQueryString()->links() }}
                    </div>
                @endif

                {{-- Bulk section --}}
                <div id="bulk-section" class="mt-6 border-t border-gray-200 pt-4">
                    <div class="flex items-center justify-between">
                        <p class="text-sm text-gray-600">
                            {{ __('Bulk update selected offers') }}
                        </p>
                        <button type="button" id="bulkToggleButton"
                                class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-semibold rounded-md
                                       text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none
                                       focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed">
                            {{ __('Mass Update') }}
                        </button>
                    </div>

                    <div id="bulkFieldsPanel" class="mt-4 hidden">
                        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3">
                            <div>
                                <label class="block text-xs font-medium text-gray-700">
                                    {{ __('Known Hops') }}
                                </label>
                                <select name="bulk_known_hops_id"
                                        class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                                    <option value="">{{ __('No change') }}</option>
                                    @foreach ($knownHopsItems as $item)
                                        <option value="{{ $item->id }}">{{ $item->label }}</option>
                                    @endforeach
                                </select>
                            </div>

                            <div>
                                <label class="block text-xs font-medium text-gray-700">
                                    {{ __('Sender Id Supported') }}
                                </label>
                                <select name="bulk_sender_id_supported_id"
                                        class="mt-1 block w-full rounded-md border-gray-300 text-xs">
                                    <option value="">{{ __('No change') }}</option>
                                    @foreach ($senderIdItems as $item)
                                        <option value="{{ $item->id }}">{{ $item->label }}</option>
                                    @endforeach
                                </select>
                            </div>

                            <div>
                                <label class="block text-xs font-medium text-gray-700">
                                    {{ __('Is Exclusive') }}
                                </label>
                                <select name="bulk_is_exclusive"
                                        class="mt-1 block w-full rounded-md border-gray-300 text-xs">
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
            // Country -> Network filter cascade
            const countrySelect = document.getElementById('filter_country_id');
            const networkSelect = document.getElementById('filter_network_id');

            if (countrySelect && networkSelect) {
                const networkOptions = Array.from(networkSelect.options);
                function updateNetworksFilter() {
                    const cid = countrySelect.value || '';
                    const current = networkSelect.value;
                    let currentValid = false;

                    networkOptions.forEach(opt => {
                        if (!opt.value) {
                            opt.hidden = false;
                            opt.disabled = false;
                            return;
                        }
                        const ocid = opt.dataset.countryId || '';
                        const show = !cid || ocid === cid;
                        opt.hidden = !show;
                        opt.disabled = !show;
                        if (show && opt.value === current) {
                            currentValid = true;
                        }
                    });

                    if (!currentValid) {
                        networkSelect.value = '';
                    }
                }
                countrySelect.addEventListener('change', updateNetworksFilter);
                updateNetworksFilter();
            }

            // Bulk section toggle
            const selectAll = document.getElementById('select_all_offers');
            const rowChecks = Array.from(document.querySelectorAll('.offer-row-checkbox'));
            const bulkBtn   = document.getElementById('bulkToggleButton');
            const bulkPanel = document.getElementById('bulkFieldsPanel');

            function updateBulkButton() {
                const anyChecked = rowChecks.some(cb => cb.checked);
                if (bulkBtn) {
                    bulkBtn.disabled = !anyChecked;
                }
                if (!anyChecked && bulkPanel) {
                    bulkPanel.classList.add('hidden');
                }
            }

            if (selectAll) {
                selectAll.addEventListener('change', function () {
                    rowChecks.forEach(cb => cb.checked = selectAll.checked);
                    updateBulkButton();
                });
            }
            rowChecks.forEach(cb => cb.addEventListener('change', updateBulkButton));

            if (bulkBtn && bulkPanel) {
                bulkBtn.addEventListener('click', function () {
                    if (!bulkBtn.disabled) {
                        bulkPanel.classList.toggle('hidden');
                    }
                });
            }

            updateBulkButton();
        });
    </script>
</x-app-layout>
