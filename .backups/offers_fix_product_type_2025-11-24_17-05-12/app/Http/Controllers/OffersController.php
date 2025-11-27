<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Country;
use App\Models\Network;
use App\Models\NetworkMnc;
use App\Models\Supplier;
use App\Models\SupplierConnection;
use App\Models\SupplierOffer;
use App\Models\DropdownItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OffersController extends Controller
{
    public function index(Request $request)
    {
        $query = SupplierOffer::with([
            'country',
            'network',
            'networkMnc',
            'supplier',
            'connection',
            'productType',
            'knownHopsItem',
            'senderIdSupportedItem',
        ]);

        if ($request->filled('country_id')) {
            $query->where('country_id', $request->input('country_id'));
        }

        if ($request->filled('network_id')) {
            $query->where('network_id', $request->input('network_id'));
        }

        if ($request->filled('supplier_id')) {
            $query->where('supplier_id', $request->input('supplier_id'));
        }

        // Exclusive filter
        if ($request->has('is_exclusive') && $request->input('is_exclusive') !== '') {
            $query->where('is_exclusive', (bool) $request->input('is_exclusive'));
        }

        $offers = $query
            ->orderBy('country_id')
            ->orderBy('network_id')
            ->orderBy('supplier_id')
            ->orderBy('price')
            ->paginate(50)
            ->appends($request->query());

        $countries   = Country::orderBy('name')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();

        $productTypeItems        = DropdownItem::where('dropdown_menu_id', 1)->orderBy('label')->get();
        $knownHopsItems          = DropdownItem::where('dropdown_menu_id', 2)->orderBy('label')->get();
        $senderIdSupportedItems  = DropdownItem::where('dropdown_menu_id', 3)->orderBy('label')->get();

        $filters = $request->only([
            'country_id',
            'network_id',
            'supplier_id',
            'is_exclusive',
        ]);

        return view('offers.index', compact(
            'offers',
            'countries',
            'suppliers',
            'networks',
            'connections',
            'productTypeItems',
            'knownHopsItems',
            'senderIdSupportedItems',
            'filters'
        ));
    }

    public function create()
    {
        $countries   = Country::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $networkMncs = NetworkMnc::orderBy('mcc_mnc')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();

        $productTypeItems        = DropdownItem::where('dropdown_menu_id', 1)->orderBy('label')->get();
        $knownHopsItems          = DropdownItem::where('dropdown_menu_id', 2)->orderBy('label')->get();
        $senderIdSupportedItems  = DropdownItem::where('dropdown_menu_id', 3)->orderBy('label')->get();

        return view('offers.create', compact(
            'countries',
            'networks',
            'networkMncs',
            'suppliers',
            'connections',
            'productTypeItems',
            'knownHopsItems',
            'senderIdSupportedItems'
        ));
    }

    public function store(Request $request)
    {
        $data = $this->validateOffer($request);

        // Normalize price: έως 6 δεκαδικά, trim trailing zeros και τελεία
        if (isset($data['price'])) {
            $normalized = number_format((float) $data['price'], 6, '.', '');
            $normalized = rtrim(rtrim($normalized, '0'), '.');
            $data['price'] = $normalized;
        }

        DB::transaction(function () use ($data) {
            SupplierOffer::create($data);
        });

        return redirect()->route('offers.index')
            ->with('status', 'Offer created successfully.');
    }

    public function edit(SupplierOffer $offer)
    {
        $countries   = Country::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $networkMncs = NetworkMnc::orderBy('mcc_mnc')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();

        $productTypeItems        = DropdownItem::where('dropdown_menu_id', 1)->orderBy('label')->get();
        $knownHopsItems          = DropdownItem::where('dropdown_menu_id', 2)->orderBy('label')->get();
        $senderIdSupportedItems  = DropdownItem::where('dropdown_menu_id', 3)->orderBy('label')->get();

        return view('offers.edit', compact(
            'offer',
            'countries',
            'networks',
            'networkMncs',
            'suppliers',
            'connections',
            'productTypeItems',
            'knownHopsItems',
            'senderIdSupportedItems'
        ));
    }

    public function update(Request $request, SupplierOffer $offer)
    {
        $data = $this->validateOffer($request, $offer);

        if (isset($data['price'])) {
            $normalized = number_format((float) $data['price'], 6, '.', '');
            $normalized = rtrim(rtrim($normalized, '0'), '.');
            $data['price'] = $normalized;
        }

        DB::transaction(function () use ($offer, $data) {
            $offer->update($data);
        });

        return redirect()->route('offers.index')
            ->with('status', 'Offer updated successfully.');
    }

    public function destroy(SupplierOffer $offer)
    {
        $offer->delete();

        return redirect()->route('offers.index')
            ->with('status', 'Offer deleted successfully.');
    }

    /**
     * Shared validation rules for create/update.
     *
     * ΣΗΜΑΝΤΙΚΟ:
     * - ΔΕΝ ζητάμε mcc / mnc / mcc_mnc από το request.
     * - Τα παράγουμε από το NetworkMnc (network_mnc_id).
     */
    protected function validateOffer(Request $request, ?SupplierOffer $offer = null): array
    {
        $validated = $request->validate([
            'country_id'                           => ['required', 'exists:countries,id'],
            'network_id'                           => ['required', 'exists:networks,id'],
            'network_mnc_id'                       => ['required', 'exists:network_mncs,id'],
            'supplier_id'                          => ['required', 'exists:suppliers,id'],
            'supplier_connection_id'               => ['required', 'exists:supplier_connections,id'],
            'price'                                => ['required', 'numeric', 'min:0'],
            // mcc / mnc / mcc_mnc ΔΕΝ έρχονται από τη φόρμα
            'product_type_dropdown_item_id'        => ['nullable', 'exists:dropdown_items,id'],
            'known_hops_dropdown_item_id'          => ['nullable', 'exists:dropdown_items,id'],
            'sender_id_supported_dropdown_item_id' => ['nullable', 'exists:dropdown_items,id'],
            'charge_type'                          => ['required', 'string', 'max:50'],
            'is_exclusive'                         => ['sometimes', 'boolean'],
            'effective_date'                       => ['required', 'date'],
        ]);

        // Normalisation για checkbox
        $validated['is_exclusive'] = $request->boolean('is_exclusive');

        // Βρίσκουμε το NetworkMnc και γεμίζουμε mcc / mnc / mcc_mnc
        $networkMnc = NetworkMnc::findOrFail($validated['network_mnc_id']);
        $validated['mcc']     = $networkMnc->mcc;
        $validated['mnc']     = $networkMnc->mnc;
        $validated['mcc_mnc'] = $networkMnc->mcc_mnc;

        return $validated;
    }
}
