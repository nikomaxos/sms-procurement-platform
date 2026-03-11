<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offers
        </h2>
    </x-slot>

    @php
        // Helper για trimmed price display
        $trimPrice = function ($value) {
            if ($value === null || $value === '') {
                return null;
            }
            $str = (string) $value;
            $str = rtrim(rtrim($str, '0'), '.');
            return $str === '' ? '0' : $str;
        };

        // Data για JS (country name <-> id)
        $countryData = $countries->map(function ($country) {
            return [
                'id' => $country->id,
                'label' => $country->name,
            ];
        })->values();

        // Map: network_id -> collection of mcc_mnc (για εμφάνιση στο network filter)
        $networkMccMncs = \App\Models\NetworkMnc::query()
            ->select('network_id', 'mcc_mnc')
            ->orderBy('mcc_mnc')
            ->get()
            ->groupBy('network_id');

        // Lookup maps για labels & user names
        $knownHopsLabels = \App\Models\DropdownItem::where('dropdown_menu_id', 2)
            ->orderBy('label')
            ->pluck('label', 'id')
            ->toArray();

        $senderIdLabels = \App\Models\DropdownItem::where('dropdown_menu_id', 3)
            ->orderBy('label')
            ->pluck('label', 'id')
            ->toArray();

        $updaterNames = \App\Models\User::query()
            ->orderBy('name')
            ->pluck('name', 'id')
            ->toArray();
    @endphp

    <div class="py-6 w-full max-w-full px-2 sm:px-4 lg:px-6 mx-auto">
        {{-- Filters --}}
        <div class="bg-white p-4 rounded-lg shadow mb-4">
            <form method="GET" action="{{ route('offers.index') }}" class="space-y-4">

                {{-- 2 σειρές filters --}}
                <div class="space-y-4">
                    {{-- Row 1: Country, Network, MCC/MNC (text), Supplier, Connection --}}
                    <div class="flex -mx-2 flex-wrap">
                        {{-- Country: single selection, search while typing --}}
                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_country_name" class="block text-sm font-medium text-gray-700">
                                Country
                            </label>
                            <input id="filter_country_name" type="text"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                                list="country_filter_options" autocomplete="off" placeholder="Search country...">
                            <datalist id="country_filter_options">
                                @foreach($countryData as $c)
                                    <option value="{{ $c['label'] }}"></option>
                                @endforeach
                            </datalist>
                            <input type="hidden" id="filter_country_id" name="country_id"
                                value="{{ request('country_id') }}">
                        </div>

                        {{-- Network: shortlist by selected country + MCCMNC in label --}}
                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_network_id" class="block text-sm font-medium text-gray-700">
                                Network
                            </label>
                            <select id="filter_network_id" name="network_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">All</option>
                                @foreach($networks as $network)
                                    @php
                                        $label = $network->name;
                                        $mccCollection = $networkMccMncs->get($network->id);
                                        $mccList = $mccCollection
                                            ? $mccCollection->pluck('mcc_mnc')->filter()->unique()->values()->all()
                                            : [];
                                        if (!empty($mccList)) {
                                            $label .= ' — ' . implode(', ', $mccList);
                                        }
                                    @endphp
                                    <option value="{{ $network->id }}" data-country-id="{{ $network->country_id ?? '' }}"
                                        @selected((string) request('network_id') === (string) $network->id)>
                                        {{ $label }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- MCC/MNC text search --}}
                        <div class="flex-1 px-2 min-w-[10rem]">
                            <label for="filter_mcc_mnc" class="block text-sm font-medium text-gray-700">
                                MCC/MNC
                            </label>
                            <input id="filter_mcc_mnc" name="mcc_mnc" type="text" value="{{ request('mcc_mnc') }}"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" placeholder="e.g. 20201"
                                autocomplete="off">
                        </div>

                        {{-- Supplier --}}
                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_supplier_id" class="block text-sm font-medium text-gray-700">
                                Supplier
                            </label>
                            <select id="filter_supplier_id" name="supplier_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">All</option>
                                @foreach($suppliers as $supplier)
                                    <option value="{{ $supplier->id }}"
                                        @selected((string) request('supplier_id') === (string) $supplier->id)>
                                        {{ $supplier->name }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Connection --}}
                        <div class="flex-1 px-2 min-w-[12rem]">
                            <label for="filter_connection_id" class="block text-sm font-medium text-gray-700">
                                Connection
                            </label>
                            <select id="filter_connection_id" name="supplier_connection_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">All</option>
                                @foreach($connections as $connection)
                                    <option value="{{ $connection->id }}"
                                        @selected((string) request('supplier_connection_id') === (string) $connection->id)>
                                        {{ $connection->name }}
                                    </option>
                                @endforeach
                            </select>
                        </div>
                    </div>

                    {{-- Row 2: Product Type, Known Hops, Sender ID Supported, Charge Type --}}
                    <div class="flex -mx-2">
                        {{-- Product Type (string-based filter) --}}
                        <div class="flex-1 px-2">
                            <label for="filter_product_type" class="block text-sm font-medium text-gray-700">
                                Product Type
                            </label>
                            <select id="filter_product_type" name="product_type"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">All</option>
                                @foreach($productTypeFilterOptions as $pt)
                                    <option value="{{ $pt }}" @selected(request('product_type') === $pt)>
                                        {{ $pt }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Known Hops --}}
                        <div class="flex-1 px-2">
                            <label for="filter_known_hops" class="block text-sm font-medium text-gray-700">
                                Known Hops
                            </label>
                            <select id="filter_known_hops" name="known_hops_dropdown_item_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">All</option>
                                @foreach($knownHopsFilterOptions as $item)
                                    <option value="{{ $item->id }}"
                                        @selected((string) request('known_hops_dropdown_item_id') === (string) $item->id)>
                                        {{ $item->label }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Sender ID Supported --}}
                        <div class="flex-1 px-2">
                            <label for="filter_sender_id_supported" class="block text-sm font-medium text-gray-700">
                                Sender ID Supported
                            </label>
                            <select id="filter_sender_id_supported" name="sender_id_supported_dropdown_item_id"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">All</option>
                                @foreach($senderIdFilterOptions as $item)
                                    <option value="{{ $item->id }}"
                                        @selected((string) request('sender_id_supported_dropdown_item_id') === (string) $item->id)>
                                        {{ $item->label }}
                                    </option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Charge Type --}}
                        <div class="flex-1 px-2">
                            <label for="filter_charge_type" class="block text-sm font-medium text-gray-700">
                                Charge Type
                            </label>
                            <select id="filter_charge_type" name="charge_type"
                                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                                <option value="">All</option>
                                @foreach($chargeTypeFilterOptions as $ct)
                                    <option value="{{ $ct }}" @selected(request('charge_type') === $ct)>
                                        {{ ucwords(str_replace('_', ' ', $ct)) }}
                                    </option>
                                @endforeach
                            </select>
                        </div>
                    </div>
                </div>

                <div class="flex justify-end gap-2 pt-4">
                    <a href="{{ route('offers.index') }}"
                        class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm rounded-md bg-white text-gray-700 hover:bg-gray-50">
                        Clear
                    </a>
                    <button type="submit"
                        class="inline-flex items-center px-4 py-2 border border-transparent text-sm rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                        Apply Filters
                    </button>
                </div>
            </form>
        </div>

        {{-- Results table --}}
        <div class="bg-white p-4 rounded-lg shadow">
            <div class="flex justify-end mb-3">
                <a href="{{ route('offers.create') }}"
                    class="inline-flex items-center px-4 py-2 border border-green-300 text-sm font-medium rounded-md shadow-sm bg-green-100 text-green-800 hover:bg-green-200">
                    Create Offer
                </a>
            </div>

            <div class="overflow-x-auto">
                <table class="min-w-full text-sm">
                    <thead>
                        <tr class="border-b bg-gray-50">
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Country</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Network</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">MCC/MNC</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Supplier</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Connection
                            </th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Conn. Username
                            </th>
                            <th class="px-3 py-2 text-right font-semibold text-gray-700 whitespace-nowrap">Price</th>
                            <th class="px-3 py-2 text-center font-semibold text-gray-700 whitespace-nowrap">History</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Product Type
                            </th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Known Hops
                            </th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Sender ID
                                Supported</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Charge Type
                            </th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Effective Date
                            </th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Last Edited
                            </th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Edited By</th>
                            <th class="px-3 py-2 text-right font-semibold text-gray-700 whitespace-nowrap">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($offers as $offer)
                            <tr class="border-b last:border-0 hover:bg-gray-50">
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->country)->name ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->network)->name ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->networkMnc)->mcc_mnc ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->supplier)->name ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->connection)->name ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->connection)->username ?? '—' }}
                                </td>
                                <td class="px-3 py-2 text-right whitespace-nowrap">
                                    {{ $trimPrice($offer->price) ?? '—' }}
                                </td>
                                <td class="px-3 py-2 text-center whitespace-nowrap">
                                    @if($offer->histories->count() > 0)
                                        <button type="button" onclick="openHistoryModal({{ $offer->id }})"
                                            class="text-xs text-blue-600 hover:underline">
                                            View ({{ $offer->histories->count() }})
                                        </button>

                                        <div id="history-data-{{ $offer->id }}" class="hidden">
                                            @php
                                                $historyList = $offer->histories;
                                            @endphp
                                            @foreach($historyList as $index => $hist)
                                                @php
                                                    if ($index < $historyList->count() - 1) {
                                                        $entryDate = $historyList[$index + 1]->created_at;
                                                    } else {
                                                        $entryDate = $offer->created_at;
                                                    }
                                                @endphp
                                                <div class="hist-row" 
                                                    data-price="{{ $trimPrice($hist->price) ?? '—' }}"
                                                    data-entry="{{ $entryDate ? $entryDate->timezone('Europe/Athens')->format('Y-m-d H:i') : '—' }}"
                                                    data-date="{{ $hist->created_at ? $hist->created_at->timezone('Europe/Athens')->format('Y-m-d H:i') : '—' }}"
                                                    data-product="{{ $hist->product_type ?? '—' }}"
                                                    data-charge="{{ $hist->charge_type ? ucwords(str_replace('_', ' ', $hist->charge_type)) : '—' }}">
                                                </div>
                                            @endforeach
                                        </div>
                                    @else
                                        <span class="text-xs text-gray-400">—</span>
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->productTypeDropdown)->label ?? ($offer->product_type ?? '—') }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @php
                                        $khId = $offer->known_hops_dropdown_item_id;
                                    @endphp
                                    {{ isset($knownHopsLabels[$khId]) ? $knownHopsLabels[$khId] : '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @php
                                        $sidId = $offer->sender_id_supported_dropdown_item_id;
                                    @endphp
                                    {{ isset($senderIdLabels[$sidId]) ? $senderIdLabels[$sidId] : '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @if($offer->charge_type)
                                        {{ ucwords(str_replace('_', ' ', $offer->charge_type)) }}
                                    @else
                                        —
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @if($offer->effective_date)
                                        {{ $offer->effective_date->timezone('Europe/Athens')->format('Y-m-d') }}
                                    @else
                                        —
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @if($offer->updated_at)
                                        {{ $offer->updated_at->timezone('Europe/Athens')->format('Y-m-d H:i') }}
                                    @else
                                        —
                                    @endif
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    @php
                                        $updId = $offer->updated_by;
                                    @endphp
                                    {{ isset($updaterNames[$updId]) ? $updaterNames[$updId] : '—' }}
                                </td>
                                <td class="px-3 py-2 text-right whitespace-nowrap">
                                    <div class="inline-flex items-center gap-2">
                                        <a href="{{ route('offers.edit', $offer) }}"
                                            class="text-blue-600 hover:underline text-sm">
                                            Edit
                                        </a>
                                        <form method="POST" action="{{ route('offers.destroy', $offer) }}"
                                            onsubmit="return confirm('Are you sure you want to delete this offer?');"
                                            class="inline-block">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit" class="text-red-600 hover:underline text-sm">
                                                Delete
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="16" class="px-3 py-4 text-center text-gray-500">
                                    No offers found.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div class="mt-4">
                {{ $offers->withQueryString()->links() }}
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const countryData = @json($countryData);
            const countryInput = document.getElementById('filter_country_name');
            const countryIdHidden = document.getElementById('filter_country_id');
            const networkSelect = document.getElementById('filter_network_id');

            if (!countryInput || !countryIdHidden || !networkSelect) {
                return;
            }

            function getCountryLabelById(id) {
                if (!id) return '';
                const item = countryData.find(c => String(c.id) === String(id));
                return item ? item.label : '';
            }

            function getCountryIdByLabel(label) {
                if (!label) return '';
                const trimmed = label.trim().toLowerCase();
                const item = countryData.find(c => c.label.trim().toLowerCase() === trimmed);
                return item ? item.id : '';
            }

            const initialCountryId = countryIdHidden.value;
            if (initialCountryId) {
                const label = getCountryLabelById(initialCountryId);
                if (label) {
                    countryInput.value = label;
                }
            }

            function filterNetworks() {
                const cid = countryIdHidden.value;

                Array.from(networkSelect.options).forEach(option => {
                    if (option.value === '') {
                        option.hidden = false;
                        return;
                    }
                    const optCountry = option.getAttribute('data-country-id') || '';
                    if (cid) {
                        option.hidden = (option.value !== '' && String(optCountry) !== String(cid));
                    } else {
                        option.hidden = false;
                    }
                });

                const selected = networkSelect.selectedOptions[0];
                if (selected && selected.hidden) {
                    networkSelect.value = '';
                }
            }

            function syncCountryIdFromInput() {
                const label = countryInput.value;
                const id = getCountryIdByLabel(label);
                countryIdHidden.value = id || '';
                filterNetworks();
            }

            countryInput.addEventListener('blur', syncCountryIdFromInput);

            countryInput.addEventListener('keydown', function (e) {
                if (e.key === 'Enter') {
                    syncCountryIdFromInput();
                }
            });

            filterNetworks();
        });

        function openHistoryModal(offerId) {
            const container = document.getElementById('history-data-' + offerId);
            const tbody = document.getElementById('historyModalBody');
            tbody.innerHTML = '';

            if (container) {
                const rows = container.querySelectorAll('.hist-row');
                rows.forEach(row => {
                    const tr = document.createElement('tr');
                    tr.className = 'hover:bg-gray-50';
                    tr.innerHTML = `
                        <td class="px-3 py-2 whitespace-nowrap text-gray-600">${row.getAttribute('data-entry')}</td>
                        <td class="px-3 py-2 whitespace-nowrap text-gray-600">${row.getAttribute('data-date')}</td>
                        <td class="px-3 py-2 whitespace-nowrap text-right font-medium">${row.getAttribute('data-price')}</td>
                        <td class="px-3 py-2 whitespace-nowrap text-gray-600">${row.getAttribute('data-product')}</td>
                        <td class="px-3 py-2 whitespace-nowrap text-gray-600">${row.getAttribute('data-charge')}</td>
                    `;
                    tbody.appendChild(tr);
                });
            }

            document.getElementById('historyModal').classList.remove('hidden');
        }

        function closeHistoryModal() {
            document.getElementById('historyModal').classList.add('hidden');
        }
    </script>

    <!-- History Modal -->
    <div id="historyModal" class="fixed inset-0 z-50 hidden overflow-y-auto" aria-labelledby="modal-title" role="dialog"
        aria-modal="true">
        <div class="flex items-start justify-center min-h-screen px-4 pt-10 pb-20 text-center sm:block sm:p-0">
            <div class="fixed inset-0 transition-opacity bg-gray-500 bg-opacity-75" aria-hidden="true"
                onclick="closeHistoryModal()"></div>
            <span class="hidden sm:inline-block sm:align-top sm:h-screen" aria-hidden="true">&#8203;</span>
            <div
                class="inline-block overflow-hidden text-left align-top transition-all transform bg-white rounded-lg shadow-xl sm:my-8 sm:align-top sm:max-w-2xl sm:w-full">
                <div class="px-4 pt-5 pb-4 bg-white sm:p-6 sm:pb-4">
                    <div class="sm:flex sm:items-start">
                        <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                            <h3 class="text-lg font-medium leading-6 text-gray-900" id="modal-title">Pricing History
                            </h3>
                            <div class="mt-4">
                                <table class="min-w-full text-sm divide-y divide-gray-200">
                                    <thead class="bg-gray-50">
                                        <tr>
                                            <th class="px-3 py-2 text-left font-semibold text-gray-700">Entry Date</th>
                                            <th class="px-3 py-2 text-left font-semibold text-gray-700">Date Changed</th>
                                            <th class="px-3 py-2 text-right font-semibold text-gray-700">Historic Price</th>
                                            <th class="px-3 py-2 text-left font-semibold text-gray-700">Product Type</th>
                                            <th class="px-3 py-2 text-left font-semibold text-gray-700">Charge Type</th>
                                        </tr>
                                    </thead>
                                    <tbody id="historyModalBody" class="divide-y divide-gray-200">
                                        <!-- Injected by JS -->
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="px-4 py-3 bg-gray-50 sm:px-6 sm:flex sm:flex-row-reverse">
                    <button type="button" onclick="closeHistoryModal()"
                        class="inline-flex justify-center w-full px-4 py-2 mt-3 text-base font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm">
                        Close
                    </button>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>