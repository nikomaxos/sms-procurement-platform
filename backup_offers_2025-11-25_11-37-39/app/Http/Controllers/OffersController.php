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
    /**
     * Display a listing of the offers with filters.
     */
    public function index(Request $request)
    {
        $query = SupplierOffer::query()
            ->with([
                'country',
                'network',
                'networkMnc',
                'supplier',
                'connection',
            ]);

        // Basic filters from request
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

        $offers = $query
            ->orderBy('country_id')
            ->orderBy('network_id')
            ->orderBy('supplier_id')
            ->orderBy('price')
            ->paginate(50)
            ->withQueryString();

        // Collections for dropdowns / filters in index.blade.php
        $countries   = Country::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();

        // Distinct product_type values from offers table
        $productTypeFilterOptions = SupplierOffer::query()
            ->select('product_type')
            ->whereNotNull('product_type')
            ->distinct()
            ->orderBy('product_type')
            ->pluck('product_type');

        // Known Hops dropdown items (menu_id = 2)
        $knownHopsFilterOptions = DropdownItem::where('dropdown_menu_id', 2)
            ->orderBy('label')
            ->get();

        // Sender ID Supported dropdown items (menu_id = 3)
        $senderIdFilterOptions = DropdownItem::where('dropdown_menu_id', 3)
            ->orderBy('label')
            ->get();

        return view('offers.index', [
            'offers'                   => $offers,
            'countries'                => $countries,
            'networks'                 => $networks,
            'suppliers'                => $suppliers,
            'connections'              => $connections,
            'productTypeFilterOptions' => $productTypeFilterOptions,
            'knownHopsFilterOptions'   => $knownHopsFilterOptions,
            'senderIdFilterOptions'    => $senderIdFilterOptions,
        ]);
    }

    /**
     * Show the form for editing the specified offer.
     */
    public function edit(SupplierOffer $offer)
    {
        $countries   = Country::orderBy('name')->get();
        $suppliers   = Supplier::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get();
        $networkMncs = NetworkMnc::orderBy('mcc_mnc')->get();

        // Options for select boxes in edit.blade.php
        $productTypeOptions = DropdownItem::where('dropdown_menu_id', 1)
            ->orderBy('label')
            ->get();

        $knownHopsOptions = DropdownItem::where('dropdown_menu_id', 2)
            ->orderBy('label')
            ->get();

        $senderIdOptions = DropdownItem::where('dropdown_menu_id', 3)
            ->orderBy('label')
            ->get();

        return view('offers.edit', [
            'offer'              => $offer,
            'countries'          => $countries,
            'suppliers'          => $suppliers,
            'networks'           => $networks,
            'connections'        => $connections,
            'networkMncs'        => $networkMncs,
            'productTypeOptions' => $productTypeOptions,
            'knownHopsOptions'   => $knownHopsOptions,
            'senderIdOptions'    => $senderIdOptions,
        ]);
    }

    /**
     * Update the specified offer in storage.
     */
    public function update(Request $request, SupplierOffer $offer)
    {
        $validated = $request->validate([
            'country_id'                         => ['required', 'integer'],
            'network_id'                         => ['required', 'integer'],
            'network_mnc_id'                     => ['nullable', 'integer'],
            'supplier_id'                        => ['required', 'integer'],
            'supplier_connection_id'             => ['nullable', 'integer'],
            'price'                              => ['required', 'numeric'],
            'mcc'                                => ['nullable', 'string', 'max:10'],
            'mnc'                                => ['nullable', 'string', 'max:10'],
            'mcc_mnc'                            => ['nullable', 'string', 'max:10'],
            'product_type'                       => ['nullable', 'string', 'max:255'],
            'product_type_id'                    => ['nullable', 'integer'],
            'known_hops_dropdown_item_id'        => ['nullable', 'integer'],
            'sender_id_supported_dropdown_item_id' => ['nullable', 'integer'],
            'route_type_id'                      => ['nullable', 'integer'],
            'charge_model_id'                    => ['nullable', 'integer'],
            'charge_type'                        => ['nullable', 'string', 'max:50'],
            'is_exclusive'                       => ['nullable', 'boolean'],
            'effective_date'                     => ['nullable', 'date'],
        ]);

        // Normalise checkbox
        if (! $request->has('is_exclusive')) {
            $validated['is_exclusive'] = false;
        }

        $offer->update($validated);

        return redirect()
            ->route('offers.index')
            ->with('status', 'Offer updated successfully.');
    }
}
