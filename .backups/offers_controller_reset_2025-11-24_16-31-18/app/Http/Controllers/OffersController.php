<?php

namespace App\Http\Controllers;

use App\Models\Country;
use App\Models\DropdownItem;
use App\Models\Network;
use App\Models\NetworkMnc;
use App\Models\Supplier;
use App\Models\SupplierConnection;
use App\Models\SupplierOffer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OffersController extends Controller
{
    public function index(Request $request)
    {
        $perPage = (int) $request->input('per_page', 50);
        $perPage = max(10, min($perPage, 200));

        $countryId        = $request->input('country_id');
        $countryLabel     = $request->input('country_label');
        $networkId        = $request->input('network_id');
        $networkMncId     = $request->input('network_mnc_id');
        $mccmnc           = trim((string) $request->input('mccmnc', ''));
        $supplierId       = $request->input('supplier_id');
        $supplierLabel    = $request->input('supplier_label');
        $connectionId     = $request->input('supplier_connection_id');
        $productType      = $request->input('product_type');
        $knownHops        = $request->input('known_hops');
        $senderIdSupported = $request->input('sender_id_supported');
        $chargeType       = $request->input('charge_type');
        $isExclusive      = $request->input('is_exclusive'); // '', '1', '0'
        $priceMin         = $request->input('price_min');
        $priceMax         = $request->input('price_max');
        $effectiveFrom    = $request->input('effective_from');
        $effectiveTo      = $request->input('effective_to');

        $query = SupplierOffer::with([
            'country',
            'network',
            'networkMnc',
            'supplier',
            'connection',
            
        ]);

        if ($countryId) {
            $query->where('country_id', $countryId);
        }
        if ($networkId) {
            $query->where('network_id', $networkId);
        }
        if ($networkMncId) {
            $query->where('network_mnc_id', $networkMncId);
        }
        if ($mccmnc !== '') {
            $query->where('mcc_mnc', 'like', $mccmnc.'%');
        }
        if ($supplierId) {
            $query->where('supplier_id', $supplierId);
        }
        if ($connectionId) {
            $query->where('supplier_connection_id', $connectionId);
        }
        if ($productType !== null && $productType !== '') {
            $query->where('product_type', $productType);
        }
        if ($knownHops !== null && $knownHops !== '') {
            $query->where('known_hops', $knownHops);
        }
        if ($senderIdSupported !== null && $senderIdSupported !== '') {
            $query->where('sender_id_supported', $senderIdSupported);
        }
        if ($chargeType !== null && $chargeType !== '') {
            $query->where('charge_type', $chargeType);
        }
        if ($isExclusive === '1') {
            $query->where('is_exclusive', true);
        } elseif ($isExclusive === '0') {
            $query->where('is_exclusive', false);
        }

        if ($priceMin !== null && $priceMin !== '') {
            $query->where('price', '>=', $priceMin);
        }
        if ($priceMax !== null && $priceMax !== '') {
            $query->where('price', '<=', $priceMax);
        }
        if ($effectiveFrom) {
            $query->whereDate('effective_date', '>=', $effectiveFrom);
        }
        if ($effectiveTo) {
            $query->whereDate('effective_date', '<=', $effectiveTo);
        }

        $offers = $query
            ->orderBy('country_id')
            ->orderBy('network_id')
            ->orderBy('supplier_id')
            ->orderBy('price')
            ->paginate($perPage)
            ->withQueryString();

        $countries          = Country::orderBy('name')->get();
        $suppliers          = Supplier::orderBy('name')->get();
        $productTypeOptions = $this->getProductTypeOptions();
        $knownHopsOptions   = $this->getKnownHopsOptions();
        $senderIdOptions    = $this->getSenderIdOptions();

        $networkOptions    = collect();
        $networkMncOptions = collect();
        $connectionOptions = collect();

        if ($countryId) {
            $networkOptions = Network::where('country_id', $countryId)
                ->orderBy('name')
                ->get();
        }

        if ($networkId) {
            $networkMncOptions = NetworkMnc::where('network_id', $networkId)
                ->orderBy('mnc')
                ->get();
        }

        if ($supplierId) {
            $connectionOptions = SupplierConnection::where('supplier_id', $supplierId)
                ->orderBy('name')
                ->get();
        }

        return view('offers.index', [
            'offers'            => $offers,
            'perPage'           => $perPage,
            'countries'         => $countries,
            'suppliers'         => $suppliers,
            'productTypeOptions'=> $productTypeOptions,
            'knownHopsOptions'  => $knownHopsOptions,
            'senderIdOptions'   => $senderIdOptions,
            'networkOptions'    => $networkOptions,
            'networkMncOptions' => $networkMncOptions,
            'connectionOptions' => $connectionOptions,
            'filters'           => [
                'country_id'           => $countryId,
                'country_label'        => $countryLabel,
                'network_id'           => $networkId,
                'network_mnc_id'       => $networkMncId,
                'mccmnc'               => $mccmnc,
                'supplier_id'          => $supplierId,
                'supplier_label'       => $supplierLabel,
                'supplier_connection_id'=> $connectionId,
                'product_type'         => $productType,
                'known_hops'           => $knownHops,
                'sender_id_supported'  => $senderIdSupported,
                'charge_type'          => $chargeType,
                'is_exclusive'         => $isExclusive,
                'price_min'            => $priceMin,
                'price_max'            => $priceMax,
                'effective_from'       => $effectiveFrom,
                'effective_to'         => $effectiveTo,
            ],
        ]);
    }

    public function create()
    {
        $countries   = Country::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get(['id', 'name', 'country_id']);
        $networkMncs = NetworkMnc::orderBy('mcc_mnc')->get(['id', 'network_id', 'mcc', 'mnc', 'mcc_mnc']);
        $suppliers   = Supplier::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get([
            'id',
            'supplier_id',
            'name',
            'username',
            'product_type',
            'charge_type',
        ]);

        $productTypeOptions = $this->getProductTypeOptions();
        $knownHopsOptions   = $this->getKnownHopsOptions();
        $senderIdOptions    = $this->getSenderIdOptions();

        return view('offers.create', [
            'countries'          => $countries,
            'networks'           => $networks,
            'networkMncs'        => $networkMncs,
            'suppliers'          => $suppliers,
            'connections'        => $connections,
            'productTypeOptions' => $productTypeOptions,
            'knownHopsOptions'   => $knownHopsOptions,
            'senderIdOptions'    => $senderIdOptions,
        ]);
    }

    public function store(Request $request)
    {
        $data = $this->validateData($request);

        return DB::transaction(function () use ($data, $request) {
            $networkMnc = NetworkMnc::findOrFail($data['network_mnc_id']);
            $connection = SupplierConnection::findOrFail($data['supplier_connection_id']);

            $data['mcc']     = (string) $networkMnc->mcc;
            $data['mnc']     = (string) $networkMnc->mnc;
            $data['mcc_mnc'] = (string) $networkMnc->mcc_mnc;

            if (empty($data['product_type']) && ! empty($connection->product_type)) {
                $data['product_type'] = $connection->product_type;
            }
            if (empty($data['charge_type']) && ! empty($connection->charge_type)) {
                $data['charge_type'] = $connection->charge_type;
            }
            if (empty($data['effective_date'])) {
                $data['effective_date'] = now()->toDateString();
            }

            $existing = SupplierOffer::where('supplier_connection_id', $data['supplier_connection_id'])
                ->where('network_mnc_id', $data['network_mnc_id'])
                ->first();

            if ($existing) {
                if (
                    (float) $existing->price !== (float) $data['price'] ||
                    (string) $existing->effective_date !== (string) $data['effective_date']
                ) {
                    }

                $existing->update($data);
                $offer = $existing;
            } else {
                $offer = SupplierOffer::create($data);
            }

            return redirect()
                ->route('offers.index')
                ->with('status', 'Offer saved.');
        });
    }

    public function edit(SupplierOffer $offer)
    {
        $offer->load(['country', 'network', 'networkMnc', 'supplier', 'connection']);

        $countries   = Country::orderBy('name')->get();
        $networks    = Network::orderBy('name')->get(['id', 'name', 'country_id']);
        $networkMncs = NetworkMnc::orderBy('mcc_mnc')->get(['id', 'network_id', 'mcc', 'mnc', 'mcc_mnc']);
        $suppliers   = Supplier::orderBy('name')->get();
        $connections = SupplierConnection::orderBy('name')->get([
            'id',
            'supplier_id',
            'name',
            'username',
            'product_type',
            'charge_type',
        ]);

        $productTypeOptions = $this->getProductTypeOptions();
        $knownHopsOptions   = $this->getKnownHopsOptions();
        $senderIdOptions    = $this->getSenderIdOptions();

        return view('offers.edit', [
            'offer'             => $offer,
            'countries'         => $countries,
            'networks'          => $networks,
            'networkMncs'       => $networkMncs,
            'suppliers'         => $suppliers,
            'connections'       => $connections,
            'productTypeOptions'=> $productTypeOptions,
            'knownHopsOptions'  => $knownHopsOptions,
            'senderIdOptions'   => $senderIdOptions,
        ]);
    }

    public function update(Request $request, SupplierOffer $offer)
    {
        $data = $this->validateData($request);

        return DB::transaction(function () use ($data, $offer, $request) {
            $networkMnc = NetworkMnc::findOrFail($data['network_mnc_id']);
            $connection = SupplierConnection::findOrFail($data['supplier_connection_id']);

            $data['mcc']     = (string) $networkMnc->mcc;
            $data['mnc']     = (string) $networkMnc->mnc;
            $data['mcc_mnc'] = (string) $networkMnc->mcc_mnc;

            if (empty($data['product_type']) && ! empty($connection->product_type)) {
                $data['product_type'] = $connection->product_type;
            }
            if (empty($data['charge_type']) && ! empty($connection->charge_type)) {
                $data['charge_type'] = $connection->charge_type;
            }
            if (empty($data['effective_date'])) {
                $data['effective_date'] = now()->toDateString();
            }

            $priceChanged = (
                (float) $offer->price !== (float) $data['price'] ||
                (string) $offer->effective_date !== (string) $data['effective_date']
            );

            if ($priceChanged) {
                }

            $offer->update($data);

            return redirect()
                ->route('offers.index')
                ->with('status', 'Offer updated.');
        });
    }

    public function destroy(SupplierOffer $offer)
    {
        $offer->delete();

        return redirect()
            ->route('offers.index')
            ->with('status', 'Offer deleted.');
    }

    public function history(SupplierOffer $offer)
    {
        $offer->load(['country', 'network', 'networkMnc', 'supplier', 'connection']);


            ->orderByDesc('effective_date')
            ->orderByDesc('created_at')
            ->get();

        return view('offers.history', [
            'offer'   => $offer,
            'history' => $history,
        ]);
    }

    public function bulkUpdate(Request $request)
    {
        $ids = $request->input('offer_ids', []);
        if (! is_array($ids) || empty($ids)) {
            return redirect()
                ->route('offers.index')
                ->with('status', 'No offers selected for bulk update.');
        }

        $data = $request->validate([
            'bulk_route_type'          => ['nullable', 'string', 'max:255'],
            'bulk_known_hops'         => ['nullable', 'string', 'max:255'],
            'bulk_sender_id_supported'=> ['nullable', 'string', 'max:255'],
            'bulk_charge_type'        => ['nullable', 'string', 'in:per_submit,per_delivered'],
            'bulk_is_exclusive'       => ['nullable', 'in:0,1'],
        ]);

        $payload = [];

        if (isset($data['bulk_route_type']) && $data['bulk_route_type'] !== '') {
            $payload['route_type'] = $data['bulk_route_type'];
        }
        if (isset($data['bulk_known_hops']) && $data['bulk_known_hops'] !== '') {
            $payload['known_hops'] = $data['bulk_known_hops'];
        }
        if (isset($data['bulk_sender_id_supported']) && $data['bulk_sender_id_supported'] !== '') {
            $payload['sender_id_supported'] = $data['bulk_sender_id_supported'];
        }
        if (isset($data['bulk_charge_type']) && $data['bulk_charge_type'] !== '') {
            $payload['charge_type'] = $data['bulk_charge_type'];
        }
        if (isset($data['bulk_is_exclusive']) && $data['bulk_is_exclusive'] !== '') {
            $payload['is_exclusive'] = $data['bulk_is_exclusive'] === '1';
        }

        if (empty($payload)) {
            return redirect()
                ->route('offers.index')
                ->with('status', 'No bulk changes specified.');
        }

        SupplierOffer::whereIn('id', $ids)->update($payload);

        return redirect()
            ->route('offers.index')
            ->with('status', 'Bulk update applied.');
    }

    protected function validateData(Request $request): array
    {
        $data = $request->validate([
            'country_id'             => ['required', 'exists:countries,id'],
            'network_id'             => ['required', 'exists:networks,id'],
            'network_mnc_id'         => ['required', 'exists:network_mncs,id'],
            'price'                  => ['required', 'numeric', 'min:0'],
            'supplier_id'            => ['required', 'exists:suppliers,id'],
            'supplier_connection_id' => ['required', 'exists:supplier_connections,id'],
            'product_type'           => ['nullable', 'string', 'max:255'],
            'known_hops'             => ['nullable', 'string', 'max:255'],
            'sender_id_supported'    => ['nullable', 'string', 'max:255'],
            'charge_type'            => ['nullable', 'string', 'in:per_submit,per_delivered'],
            'is_exclusive'           => ['sometimes', 'boolean'],
            'route_type'             => ['nullable', 'string', 'max:255'],
            'effective_date'         => ['nullable', 'date'],
        ]);

        $data['is_exclusive'] = $request->boolean('is_exclusive');

        return $data;
    }

    protected function getProductTypeOptions(): array
    {
        return DropdownItem::where('dropdown_menu_id', 1)
            ->orderBy('label')
            ->pluck('label', 'label')
            ->toArray();
    }

    protected function getKnownHopsOptions(): array
    {
        return DropdownItem::where('dropdown_menu_id', 2)
            ->orderBy('label')
            ->pluck('label', 'label')
            ->toArray();
    }

    protected function getSenderIdOptions(): array
    {
        return DropdownItem::where('dropdown_menu_id', 3)
            ->orderBy('label')
            ->pluck('label', 'label')
            ->toArray();
    }
}
