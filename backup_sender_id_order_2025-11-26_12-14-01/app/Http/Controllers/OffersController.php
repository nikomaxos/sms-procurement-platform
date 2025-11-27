<?php

namespace App\Http\Controllers;

use App\Models\SupplierOffer;
use App\Models\Country;
use App\Models\Network;
use App\Models\NetworkMnc;
use App\Models\Supplier;
use App\Models\SupplierConnection;
use App\Models\DropdownItem;
use Illuminate\Http\Request;

class OffersController extends Controller
{
    public function index(Request $request)
    {
        $query = SupplierOffer::query()
            ->with([
                'country',
                'network',
                'networkMnc',
                'supplier',
                'connection',
                'productTypeDropdown',
                'knownHopsDropdown',
                'senderIdSupportedDropdown',
                'updater',
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

        if ($request->filled('supplier_connection_id')) {
            $query->where('supplier_connection_id', $request->input('supplier_connection_id'));
        }

        if ($request->filled('product_type')) {
            $query->where('product_type', $request->input('product_type'));
        }

        if ($request->filled('known_hops_dropdown_item_id')) {
            $query->where('known_hops_dropdown_item_id', $request->input('known_hops_dropdown_item_id'));
        }

        if ($request->filled('sender_id_supported_dropdown_item_id')) {
            $query->where('sender_id_supported_dropdown_item_id', $request->input('sender_id_supported_dropdown_item_id'));
        }

        if ($request->filled('charge_type')) {
            $query->where('charge_type', $request->input('charge_type'));
        }

        $offers = $query
            ->orderBy('country_id')
            ->orderBy('network_id')
            ->orderBy('supplier_id')
            ->orderBy('price')
            ->paginate(50)
            ->appends($request->query());

        $countries   = Country::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();

        $productTypeFilterOptions = SupplierOffer::query()
            ->select('product_type')
            ->whereNotNull('product_type')
            ->distinct()
            ->orderBy('product_type')
            ->pluck('product_type');

        $knownHopsFilterOptions = DropdownItem::where('dropdown_menu_id', 2)
            ->orderBy('label')
            ->get();

        $senderIdFilterOptions = DropdownItem::where('dropdown_menu_id', 3)
            ->orderBy('label')
            ->get();

        $chargeTypeFilterOptions = SupplierOffer::query()
            ->select('charge_type')
            ->whereNotNull('charge_type')
            ->distinct()
            ->orderBy('charge_type')
            ->pluck('charge_type');

        return view('offers.index', [
            'offers'                   => $offers,
            'countries'                => $countries,
            'networks'                 => $networks,
            'suppliers'                => $suppliers,
            'connections'              => $connections,
            'productTypeFilterOptions' => $productTypeFilterOptions,
            'knownHopsFilterOptions'   => $knownHopsFilterOptions,
            'senderIdFilterOptions'    => $senderIdFilterOptions,
            'chargeTypeFilterOptions'  => $chargeTypeFilterOptions,
        ]);
    }

    public function edit(SupplierOffer $offer)
    {
        $countries   = Country::orderBy('name')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();
        $networkMncs = NetworkMnc::orderBy('mcc_mnc')->get();

        $productTypeOptions = DropdownItem::where('dropdown_menu_id', 1)->orderBy('label')->get();
        $knownHopsOptions   = DropdownItem::where('dropdown_menu_id', 2)->orderBy('label')->get();
        $senderIdOptions    = DropdownItem::where('dropdown_menu_id', 3)->orderBy('label')->get();

        $chargeTypeOptions = SupplierConnection::query()
            ->select('charge_type')
            ->whereNotNull('charge_type')
            ->distinct()
            ->orderBy('charge_type')
            ->pluck('charge_type');

        $networkMncSummary = NetworkMnc::select('network_id', 'mcc', 'mnc')
            ->orderBy('network_id')
            ->orderBy('mnc')
            ->get()
            ->groupBy('network_id')
            ->map(function ($rows) {
                $mcc = $rows->first()->mcc;
                $mncs = $rows->pluck('mnc')->unique()->implode(' - ');
                return "{$mcc} / {$mncs}";
            });

        $selectedProductTypeId = null;
        if (!empty($offer->product_type_id)) {
            $selectedProductTypeId = $offer->product_type_id;
        } elseif (!empty($offer->product_type)) {
            $matching = $productTypeOptions->firstWhere('label', $offer->product_type);
            if ($matching) {
                $selectedProductTypeId = $matching->id;
            }
        }

        $selectedKnownHopsId         = $offer->known_hops_dropdown_item_id;
        $selectedSenderIdSupportedId = $offer->sender_id_supported_dropdown_item_id;

        return view('offers.edit', [
            'offer'                       => $offer,
            'countries'                   => $countries,
            'suppliers'                   => $suppliers,
            'networks'                    => $networks,
            'connections'                 => $connections,
            'networkMncs'                 => $networkMncs,
            'networkMncSummary'           => $networkMncSummary,
            'productTypeOptions'          => $productTypeOptions,
            'knownHopsOptions'            => $knownHopsOptions,
            'senderIdOptions'             => $senderIdOptions,
            'chargeTypeOptions'           => $chargeTypeOptions,
            'selectedProductTypeId'       => $selectedProductTypeId,
            'selectedKnownHopsId'         => $selectedKnownHopsId,
            'selectedSenderIdSupportedId' => $selectedSenderIdSupportedId,
        ]);
    }

    public function update(Request $request, SupplierOffer $offer)
    {
        $this->ensureNetworkMncForRequest($request);

        $validated = $request->validate([
            'country_id'                          => ['required', 'integer', 'exists:countries,id'],
            'network_id'                          => ['required', 'integer', 'exists:networks,id'],
            'network_mnc_id'                      => ['nullable', 'integer', 'exists:network_mncs,id'],
            'supplier_id'                         => ['required', 'integer', 'exists:suppliers,id'],
            'supplier_connection_id'              => ['nullable', 'integer', 'exists:supplier_connections,id'],
            'price'                               => ['required', 'numeric', 'min:0'],
            'mcc'                                 => ['nullable', 'string', 'max:4'],
            'mnc'                                 => ['nullable', 'string', 'max:4'],
            'mcc_mnc'                             => ['nullable', 'string', 'max:8'],
            'product_type_id'                     => ['nullable', 'integer', 'exists:dropdown_items,id'],
            'known_hops_dropdown_item_id'         => ['nullable', 'integer', 'exists:dropdown_items,id'],
            'sender_id_supported_dropdown_item_id'=> ['nullable', 'integer', 'exists:dropdown_items,id'],
            'route_type_id'                       => ['nullable', 'integer'],
            'charge_model_id'                     => ['nullable', 'integer'],
            'charge_type'                         => ['nullable', 'string', 'max:50'],
            'is_exclusive'                        => ['nullable', 'boolean'],
            'effective_date'                      => ['nullable', 'date'],
        ]);

        $validated['is_exclusive'] = $request->boolean('is_exclusive');

        if (isset($validated['price'])) {
            $validated['price'] = $this->normalizePrice($validated['price']);
        }

        $productTypeId = $validated['product_type_id'] ?? null;
        if ($productTypeId) {
            $dropdown = DropdownItem::find($productTypeId);
            $validated['product_type'] = $dropdown ? $dropdown->label : null;
        } else {
            $validated['product_type'] = null;
        }

        // ποιος έκανε το τελευταίο edit
        $validated['updated_by'] = optional($request->user())->id;

        $offer->update($validated);

        return redirect()
            ->route('offers.index')
            ->with('status', 'Offer updated successfully.');
    }

    private function normalizePrice($value): string
    {
        $str = (string) $value;
        $str = rtrim(rtrim($str, '0'), '.');

        if ($str === '' || $str === '-0') {
            return '0';
        }

        return $str;
    }

    public function create()
    {
        $offer = new SupplierOffer();

        $countries   = Country::orderBy('name')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();
        $networkMncs = NetworkMnc::orderBy('mcc_mnc')->get();

        $productTypeOptions = DropdownItem::where('dropdown_menu_id', 1)->orderBy('label')->get();
        $knownHopsOptions   = DropdownItem::where('dropdown_menu_id', 2)->orderBy('label')->get();
        $senderIdOptions    = DropdownItem::where('dropdown_menu_id', 3)->orderBy('label')->get();

        $selectedProductTypeId       = null;
        $selectedKnownHopsId         = null;
        $selectedSenderIdSupportedId = null;

        return view('offers.edit', compact(
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

    public function store(Request $request)
    {
        $this->ensureNetworkMncForRequest($request);

        $validated = $request->validate([
            'country_id'                          => ['required', 'integer'],
            'network_id'                          => ['required', 'integer'],
            'network_mnc_id'                      => ['nullable', 'integer'],
            'supplier_id'                         => ['required', 'integer'],
            'supplier_connection_id'              => ['required', 'integer'],
            'price'                               => ['required'],
            'product_type_id'                     => ['nullable', 'integer'],
            'known_hops_dropdown_item_id'         => ['nullable', 'integer'],
            'sender_id_supported_dropdown_item_id'=> ['nullable', 'integer'],
            'route_type_id'                       => ['nullable', 'integer'],
            'charge_model_id'                     => ['nullable', 'integer'],
            'charge_type'                         => ['nullable', 'string', 'max:255'],
            'is_exclusive'                        => ['nullable', 'boolean'],
            'effective_date'                      => ['nullable', 'date'],
        ]);

        if (isset($validated['price'])) {
            $priceStr = (string) $validated['price'];
            if (strpos($priceStr, '.') !== false) {
                $priceStr = rtrim($priceStr, '0');
                $priceStr = rtrim($priceStr, '.');
            }
            $validated['price'] = $priceStr;
        }

        $offer = new SupplierOffer();

        foreach ($validated as $key => $value) {
            $offer->{$key} = $value;
        }

        if (!empty($validated['product_type_id'])) {
            $item = DropdownItem::find($validated['product_type_id']);
            if ($item) {
                $offer->product_type = $item->label;
            }
        }

        // ποιος το δημιούργησε (για το Edited By)
        $offer->updated_by = optional($request->user())->id;

        $offer->save();

        return redirect()
            ->route('offers.edit', $offer)
            ->with('status', 'Offer created successfully.');
    }

    public function networkMncsJson($network)
    {
        $mncs = NetworkMnc::query()
            ->where('network_id', $network)
            ->orderBy('mcc_mnc')
            ->get(['id', 'mcc_mnc']);

        return response()->json([
            'mncs' => $mncs,
        ]);
    }

    public function connectionDefaultsJson($connection)
    {
        $defaults = [
            'product_type_id'    => null,
            'product_type_label' => null,
            'charge_type'        => null,
            'username'           => null,
        ];

        $conn = SupplierConnection::find($connection);
        if ($conn) {
            if (!empty($conn->charge_type)) {
                $defaults['charge_type'] = $conn->charge_type;
            }

            if (!empty($conn->product_type_id)) {
                $defaults['product_type_id'] = $conn->product_type_id;
            }
            if (empty($defaults['product_type_id']) && !empty($conn->product_type_dropdown_item_id)) {
                $defaults['product_type_id'] = $conn->product_type_dropdown_item_id;
            }

            if (!empty($conn->product_type)) {
                $defaults['product_type_label'] = $conn->product_type;
            }

            if (!empty($conn->username)) {
                $defaults['username'] = $conn->username;
            }
        }

        if (empty($defaults['product_type_id']) && empty($defaults['product_type_label'])) {
            $offer = SupplierOffer::query()
                ->where('supplier_connection_id', $connection)
                ->orderByDesc('updated_at')
                ->first();

            if ($offer) {
                if (!empty($offer->product_type_id)) {
                    $defaults['product_type_id'] = $offer->product_type_id;
                }
                if (!empty($offer->product_type)) {
                    $defaults['product_type_label'] = $offer->product_type;
                }
                if (empty($defaults['charge_type']) && !empty($offer->charge_type)) {
                    $defaults['charge_type'] = $offer->charge_type;
                }
            }
        }

        return response()->json($defaults);
    }

    public function destroy(SupplierOffer $offer)
    {
        $offer->delete();

        return redirect()
            ->route('offers.index')
            ->with('status', 'Offer deleted successfully.');
    }

    protected function ensureNetworkMncForRequest(Request $request): void
    {
        if (!$request->filled('network_id')) {
            return;
        }

        if ($request->filled('network_mnc_id')) {
            return;
        }

        $mncIds = NetworkMnc::where('network_id', $request->input('network_id'))
            ->pluck('id');

        if ($mncIds->count() === 1) {
            $request->merge([
                'network_mnc_id' => $mncIds->first(),
            ]);
        }
    }
}
