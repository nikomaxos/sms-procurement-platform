#!/usr/bin/env bash

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_create_store_$(date +%F_%H-%M-%S)"

echo "==> Backup directory: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/app/Http/Controllers" "${BACKUP_DIR}/resources/views/offers"

# Backup OffersController και τυχόν create view
if [ -f "app/Http/Controllers/OffersController.php" ]; then
  cp app/Http/Controllers/OffersController.php "${BACKUP_DIR}/app/Http/Controllers/" || echo "WARN: Could not backup OffersController.php"
else
  echo "!! app/Http/Controllers/OffersController.php not found. Aborting."
  exit 0
fi

if [ -f "resources/views/offers/create.blade.php" ]; then
  cp resources/views/offers/create.blade.php "${BACKUP_DIR}/resources/views/offers/" || echo "WARN: Could not backup existing create.blade.php"
fi

# Ελέγχει ότι η τελευταία γραμμή του controller είναι μόνο "}"
LAST_LINE_RAW="$(tail -n1 app/Http/Controllers/OffersController.php)"
LAST_LINE_TRIMMED="$(echo "${LAST_LINE_RAW}" | tr -d '[:space:]')"

if [ "${LAST_LINE_TRIMMED}" != "}" ]; then
  echo "!! Last line of OffersController.php is not a single '}'."
  echo "   Last line was: '${LAST_LINE_RAW}'"
  echo "   To avoid breaking the class, aborting without changes."
  exit 0
fi

echo "==> Appending create() and store() methods to OffersController"

TMP_FILE="${PROJECT_ROOT}/OffersController.tmp.$$"
# Κόβει την τελευταία γραμμή (κλείσιμο κλάσης)
sed '$d' app/Http/Controllers/OffersController.php > "${TMP_FILE}"

cat >> "${TMP_FILE}" << 'PHP'

    /**
     * Show the form for creating a new SupplierOffer.
     */
    public function create()
    {
        // New empty offer instance
        $offer = new SupplierOffer();

        // Collections όπως στο edit()
        $countries   = Country::orderBy('name')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();
        $networkMncs = NetworkMnc::orderBy('mcc_mnc')->get();

        // Dropdown options
        $productTypeOptions = DropdownItem::where('dropdown_menu_id', 1)->orderBy('label')->get();
        $knownHopsOptions   = DropdownItem::where('dropdown_menu_id', 2)->orderBy('label')->get();
        $senderIdOptions    = DropdownItem::where('dropdown_menu_id', 3)->orderBy('label')->get();

        // Selected IDs για τη φόρμα create (null στην αρχή)
        $selectedProductTypeId        = null;
        $selectedKnownHopsId          = null;
        $selectedSenderIdSupportedId  = null;

        return view('offers.create', compact(
            'offer',
            'countries',
            'suppliers',
            'networks',
            'connections',
            'networkMncs',
            'productTypeOptions',
            'knownHopsOptions',
            'senderIdOptions',
            'selectedProductTypeId',
            'selectedKnownHopsId',
            'selectedSenderIdSupportedId'
        ));
    }

    /**
     * Store a newly created SupplierOffer in storage.
     */
    public function store(Request $request)
    {
        // Απλό validation – μπορεί να το σφίξουμε αργότερα
        $validated = $request->validate([
            'country_id'                         => ['required', 'integer'],
            'network_id'                         => ['required', 'integer'],
            'network_mnc_id'                     => ['nullable', 'integer'],
            'supplier_id'                        => ['required', 'integer'],
            'supplier_connection_id'             => ['required', 'integer'],
            'price'                              => ['required'],
            'product_type_id'                    => ['nullable', 'integer'],
            'known_hops_dropdown_item_id'        => ['nullable', 'integer'],
            'sender_id_supported_dropdown_item_id' => ['nullable', 'integer'],
            'route_type_id'                      => ['nullable', 'integer'],
            'charge_model_id'                    => ['nullable', 'integer'],
            'charge_type'                        => ['nullable', 'string', 'max:255'],
            'is_exclusive'                       => ['nullable', 'boolean'],
            'effective_date'                     => ['nullable', 'date'],
        ]);

        // Τrim της τιμής (κόψιμο μηδενικών από τα δεξιά, π.χ. 0.03500 -> 0.035)
        if (isset($validated['price'])) {
            $priceStr = (string) $validated['price'];
            // Αν υπάρχει δεκαδικό, κόψε μηδενικά και τυχόν τελική τελεία
            if (strpos($priceStr, '.') !== false) {
                $priceStr = rtrim($priceStr, '0');
                $priceStr = rtrim($priceStr, '.');
            }
            $validated['price'] = $priceStr;
        }

        $offer = new SupplierOffer();

        // Γέμισμα βασικών πεδίων
        foreach ($validated as $key => $value) {
            $offer->{$key} = $value;
        }

        // Αν υπάρχει product_type_id, φέρε το label και κράτα και το string product_type σε sync
        if (!empty($validated['product_type_id'])) {
            $item = DropdownItem::find($validated['product_type_id']);
            if ($item) {
                $offer->product_type = $item->label;
            }
        }

        // TODO: Αν χρειαστεί, μπορούμε να παράγουμε mcc/mnc/mcc_mnc με βάση το selected NetworkMnc.
        // Προς το παρόν αφήνονται όπως είναι (πιθανόν null) και μπορείς να τα διορθώσεις στο edit.

        $offer->save();

        return redirect()
            ->route('offers.edit', $offer)
            ->with('status', 'Offer created successfully.');
    }

}
PHP

mv "${TMP_FILE}" app/Http/Controllers/OffersController.php

echo "==> Creating resources/views/offers/create.blade.php (simple create form)"

mkdir -p resources/views/offers

cat > resources/views/offers/create.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Create Offer
        </h2>
    </x-slot>

    <div class="py-6 w-full max-w-full px-2 sm:px-4 lg:px-6 mx-auto">
        @if ($errors->any())
            <div class="mb-4 bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded text-sm">
                <div class="font-semibold mb-1">Please fix the following errors:</div>
                <ul class="list-disc pl-5">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        @if (session('status'))
            <div class="mb-4 bg-green-50 border border-green-200 text-green-800 px-4 py-3 rounded text-sm">
                {{ session('status') }}
            </div>
        @endif

        <div class="bg-white p-6 rounded-lg shadow">
            <form method="POST" action="{{ route('offers.store') }}" class="grid grid-cols-1 md:grid-cols-2 gap-4">
                @csrf

                {{-- Country --}}
                <div>
                    <label for="country_id" class="block text-sm font-medium text-gray-700">Country</label>
                    <select id="country_id" name="country_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select country</option>
                        @foreach($countries as $country)
                            <option value="{{ $country->id }}" @selected(old('country_id', $offer->country_id) == $country->id)>
                                {{ $country->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Network --}}
                <div>
                    <label for="network_id" class="block text-sm font-medium text-gray-700">Network</label>
                    <select id="network_id" name="network_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select network</option>
                        @foreach($networks as $network)
                            <option value="{{ $network->id }}" @selected(old('network_id', $offer->network_id) == $network->id)>
                                {{ $network->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Supplier --}}
                <div>
                    <label for="supplier_id" class="block text-sm font-medium text-gray-700">Supplier</label>
                    <select id="supplier_id" name="supplier_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select supplier</option>
                        @foreach($suppliers as $supplier)
                            <option value="{{ $supplier->id }}" @selected(old('supplier_id', $offer->supplier_id) == $supplier->id)>
                                {{ $supplier->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Connection --}}
                <div>
                    <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">Connection</label>
                    <select id="supplier_connection_id" name="supplier_connection_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" required>
                        <option value="">Select connection</option>
                        @foreach($connections as $connection)
                            <option value="{{ $connection->id }}" @selected(old('supplier_connection_id', $offer->supplier_connection_id) == $connection->id)>
                                {{ $connection->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Network MNC --}}
                <div>
                    <label for="network_mnc_id" class="block text-sm font-medium text-gray-700">MNC</label>
                    <select id="network_mnc_id" name="network_mnc_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($networkMncs as $mnc)
                            <option value="{{ $mnc->id }}" @selected(old('network_mnc_id', $offer->network_mnc_id) == $mnc->id)>
                                {{ $mnc->mcc_mnc }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Price --}}
                <div>
                    <label for="price" class="block text-sm font-medium text-gray-700">Price</label>
                    <input id="price"
                           name="price"
                           type="text"
                           value="{{ old('price', $offer->price) }}"
                           class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                           required>
                    <p class="mt-1 text-xs text-gray-500">
                        Will be stored trimmed (e.g. 0.03500 → 0.035).
                    </p>
                </div>

                {{-- Product Type (dropdown menu 1) --}}
                <div>
                    <label for="product_type_id" class="block text-sm font-medium text-gray-700">Product Type</label>
                    <select id="product_type_id" name="product_type_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($productTypeOptions as $item)
                            <option value="{{ $item->id }}" @selected(old('product_type_id', $selectedProductTypeId) == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Known Hops (dropdown menu 2) --}}
                <div>
                    <label for="known_hops_dropdown_item_id" class="block text-sm font-medium text-gray-700">Known Hops</label>
                    <select id="known_hops_dropdown_item_id" name="known_hops_dropdown_item_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($knownHopsOptions as $item)
                            <option value="{{ $item->id }}" @selected(old('known_hops_dropdown_item_id', $selectedKnownHopsId) == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Sender ID Supported (dropdown menu 3) --}}
                <div>
                    <label for="sender_id_supported_dropdown_item_id" class="block text-sm font-medium text-gray-700">Sender ID Supported</label>
                    <select id="sender_id_supported_dropdown_item_id" name="sender_id_supported_dropdown_item_id" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option value="">(optional)</option>
                        @foreach($senderIdOptions as $item)
                            <option value="{{ $item->id }}" @selected(old('sender_id_supported_dropdown_item_id', $selectedSenderIdSupportedId) == $item->id)>
                                {{ $item->label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Charge Type --}}
                <div>
                    <label for="charge_type" class="block text-sm font-medium text-gray-700">Charge Type</label>
                    <input id="charge_type"
                           name="charge_type"
                           type="text"
                           value="{{ old('charge_type', $offer->charge_type) }}"
                           class="mt-1 block w-full border-gray-300 rounded-md shadow-sm"
                           placeholder="e.g. per_submit">
                </div>

                {{-- Is Exclusive --}}
                <div class="flex items-center mt-4">
                    <input id="is_exclusive"
                           name="is_exclusive"
                           type="checkbox"
                           value="1"
                           @checked(old('is_exclusive', $offer->is_exclusive)) 
                           class="h-4 w-4 text-indigo-600 border-gray-300 rounded">
                    <label for="is_exclusive" class="ml-2 block text-sm text-gray-700">
                        Exclusive
                    </label>
                </div>

                {{-- Effective Date --}}
                <div>
                    <label for="effective_date" class="block text-sm font-medium text-gray-700">Effective Date</label>
                    <input id="effective_date"
                           name="effective_date"
                           type="date"
                           value="{{ old('effective_date', optional($offer->effective_date)->format('Y-m-d')) }}"
                           class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                </div>

                {{-- Actions --}}
                <div class="mt-4 col-span-1 md:col-span-2 flex justify-end gap-2">
                    <a href="{{ route('offers.index') }}"
                       class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm bg-white text-gray-700 hover:bg-gray-50">
                        Cancel
                    </a>
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                        Save Offer
                    </button>
                </div>
            </form>
        </div>
    </div>
</x-app-layout>
BLADE

echo "==> Done. Backups at: ${BACKUP_DIR}"
