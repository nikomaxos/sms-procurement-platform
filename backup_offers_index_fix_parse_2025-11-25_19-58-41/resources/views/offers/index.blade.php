<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between">
            <h2 class="font-semibold text-xl text-gray-800 leading-tight">
                Offers
            </h2>

            <a href="{{ route('offers.create') }}"
               class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm bg-white text-gray-800 hover:bg-gray-50">
                Create Offer
            </a>
        </div>
    </x-slot>

    @php
        use Illuminate\Support\Str;

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
                'id'    => $country->id,
                'label' => $country->name, // εδώ απλά το όνομα (αν θέλουμε MCCs το προσαρμόζουμε αργότερα)
            ];
        })->values();
    @endphp

    <div class="py-6 w-full max-w-full px-2 sm:px-4 lg:px-6 mx-auto">
        {{-- Filters --}}
        <div class="bg-white p-4 rounded-lg shadow mb-4">
            <form method="GET" action="{{ route('offers.index') }}" class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                    {{-- Country: single selection, search while typing --}}
                    <div>
                        <label for="filter_country_name" class="block text-sm font-medium text-gray-700">
                            Country
                        </label>
                        <input
                            id="filter_country_name"
                            type="text"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                            list="country_filter_options"
                            autocomplete="off"
                            placeholder="Search country..."
                        >
                        <datalist id="country_filter_options">
                            @foreach($countryData as $c)
                                <option value="{{ $c['label'] }}"></option>
                            @endforeach
                        </datalist>
                        <input
                            type="hidden"
                            id="filter_country_id"
                            name="country_id"
                            value="{{ request('country_id') }}"
                        >
                    </div>

                    {{-- Network: shortlist by selected country --}}
                    <div>
                        <label for="filter_network_id" class="block text-sm font-medium text-gray-700">
                            Network
                        </label>
                        <select
                            id="filter_network_id"
                            name="network_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                        >
                            <option value="">All</option>
                            @foreach($networks as $network)
                                <option value="{{ $network->id }}"
                                        data-country-id="{{ $network->country_id ?? '' }}"
                                        @selected((string)request('network_id') === (string)$network->id)>
                                    {{ $network->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- Supplier --}}
                    <div>
                        <label for="filter_supplier_id" class="block text-sm font-medium text-gray-700">
                            Supplier
                        </label>
                        <select
                            id="filter_supplier_id"
                            name="supplier_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                        >
                            <option value="">All</option>
                            @foreach($suppliers as $supplier)
                                <option value="{{ $supplier->id }}"
                                        @selected((string)request('supplier_id') === (string)$supplier->id)>
                                    {{ $supplier->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- Connection --}}
                    <div>
                        <label for="filter_connection_id" class="block text-sm font-medium text-gray-700">
                            Connection
                        </label>
                        <select
                            id="filter_connection_id"
                            name="supplier_connection_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                        >
                            <option value="">All</option>
                            @foreach($connections as $connection)
                                <option value="{{ $connection->id }}"
                                        @selected((string)request('supplier_connection_id') === (string)$connection->id)>
                                    {{ $connection->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                    {{-- Product Type (string-based filter) --}}
                    <div>
                        <label for="filter_product_type" class="block text-sm font-medium text-gray-700">
                            Product Type
                        </label>
                        <select
                            id="filter_product_type"
                            name="product_type"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                        >
                            <option value="">All</option>
                            @foreach($productTypeFilterOptions as $pt)
                                <option value="{{ $pt }}"
                                        @selected(request('product_type') === $pt)>
                                    {{ $pt }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- Known Hops --}}
                    <div>
                        <label for="filter_known_hops" class="block text-sm font-medium text-gray-700">
                            Known Hops
                        </label>
                        <select
                            id="filter_known_hops"
                            name="known_hops_dropdown_item_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                        >
                            <option value="">All</option>
                            @foreach($knownHopsFilterOptions as $item)
                                <option value="{{ $item->id }}"
                                        @selected((string)request('known_hops_dropdown_item_id') === (string)$item->id)>
                                    {{ $item->label }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- Sender ID Supported --}}
                    <div>
                        <label for="filter_sender_id_supported" class="block text-sm font-medium text-gray-700">
                            Sender ID Supported
                        </label>
                        <select
                            id="filter_sender_id_supported"
                            name="sender_id_supported_dropdown_item_id"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                        >
                            <option value="">All</option>
                            @foreach($senderIdFilterOptions as $item)
                                <option value="{{ $item->id }}"
                                        @selected((string)request('sender_id_supported_dropdown_item_id') === (string)$item->id)>
                                    {{ $item->label }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    {{-- Charge Type --}}
                    <div>
                        <label for="filter_charge_type" class="block text-sm font-medium text-gray-700">
                            Charge Type
                        </label>
                        <select
                            id="filter_charge_type"
                            name="charge_type"
                            class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                        >
                            <option value="">All</option>
                            @foreach($chargeTypeFilterOptions as $ct)
                                <option value="{{ $ct }}"
                                        @selected(request('charge_type') === $ct)>
                                    {{ ucwords(str_replace('_', ' ', $ct)) }}
                                </option>
                            @endforeach
                        </select>
                    </div>
                </div>

                <div class="flex justify-end gap-2 pt-2">
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
            <div class="overflow-x-auto">
                <table class="min-w-full text-sm">
                    <thead>
                        <tr class="border-b bg-gray-50">
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Country</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Network</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">MCC/MNC</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Supplier</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Connection</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Conn. Username</th>
                            <th class="px-3 py-2 text-right font-semibold text-gray-700 whitespace-nowrap">Price</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Product Type</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Known Hops</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Sender ID Supported</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Charge Type</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Effective Date</th>
                            <th class="px-3 py-2 text-left font-semibold text-gray-700 whitespace-nowrap">Last Edited</th>
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
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->productTypeDropdown)->label ?? ($offer->product_type ?? '—') }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->knownHopsDropdownItem)->label ?? '—' }}
                                </td>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    {{ optional($offer->senderIdSupportedDropdownItem)->label ?? '—' }}
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
                                    {{ optional($offer->updater)->name ?? '—' }}
                                </td>
                                <td class="px-3 py-2 text-right whitespace-nowrap">
                                    <div class="inline-flex items-center gap-2">
                                        <a href="{{ route('offers.edit', $offer) }}"
                                           class="text-blue-600 hover:underline text-sm">
                                            Edit
                                        </a>
                                        <form method="POST"
                                              action="{{ route('offers.destroy', $offer) }}"
                                              onsubmit="return confirm('Are you sure you want to delete this offer?');"
                                              class="inline-block">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit"
                                                    class="text-red-600 hover:underline text-sm">
                                                Delete
                                            </button>
                                        </form>
                                    </div>
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

            <div class="mt-4">
                {{ $offers->withQueryString()->links() }}
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const countryData  = @json($countryData);
            const countryInput = document.getElementById('filter_country_name');
            const countryIdHidden = document.getElementById('filter_country_id');
            const networkSelect   = document.getElementById('filter_network_id');

            if (!countryInput || !countryIdHidden || !networkSelect) {
                return;
            }

            // Βοηθητική: βρες label από id
            function getCountryLabelById(id) {
                if (!id) return '';
                const item = countryData.find(c => String(c.id) === String(id));
                return item ? item.label : '';
            }

            // Βοηθητική: βρες id από label (απλό exact match)
            function getCountryIdByLabel(label) {
                if (!label) return '';
                const trimmed = label.trim().toLowerCase();
                const item = countryData.find(c => c.label.trim().toLowerCase() === trimmed);
                return item ? item.id : '';
            }

            // Αρχικοποίηση: αν υπάρχει country_id στο query, γέμισε το textfield
            const initialCountryId = countryIdHidden.value;
            if (initialCountryId) {
                const label = getCountryLabelById(initialCountryId);
                if (label) {
                    countryInput.value = label;
                }
            }

            // Φιλτράρισμα network options βάσει country_id
            function filterNetworks() {
                const cid = countryIdHidden.value;

                Array.from(networkSelect.options).forEach(option => {
                    if (option.value === '') {
                        option.hidden = false;
                        return;
                    }
                    const optCountry = option.getAttribute('data-country-id') || '';
                    option.hidden = cid && optCountry && String(optCountry) !== String(cid);
                });

                const selected = networkSelect.selectedOptions[0];
                if (selected && selected.hidden) {
                    networkSelect.value = '';
                }
            }

            // Όταν αλλάζει το text του country, ενημέρωσε το hidden id
            function syncCountryIdFromInput() {
                const label = countryInput.value;
                const id = getCountryIdByLabel(label);
                countryIdHidden.value = id || '';
                filterNetworks();
            }

            // Σε blur, συγχρόνισε
            countryInput.addEventListener('blur', syncCountryIdFromInput);

            // Σε Enter στο text field, συγχρόνισε άμεσα
            countryInput.addEventListener('keydown', function (e) {
                if (e.key === 'Enter') {
                    syncCountryIdFromInput();
                }
            });

            // Αρχικό φιλτράρισμα networks (σε περίπτωση που υπάρχει country_id στο query)
            filterNetworks();
        });
    </script>
</x-app-layout>
