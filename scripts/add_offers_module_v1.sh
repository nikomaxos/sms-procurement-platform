#!/usr/bin/env bash
set -euo pipefail

echo "==> add_offers_module_v1: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/add_offers_module_${STAMP}"
echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "   - Backing up ${f}"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    cp "$f" "${BACKUP_DIR}/${f}"
  fi
}

# Back up files we might touch/create
backup_file "app/Models/SupplierOffer.php"
backup_file "app/Models/SupplierOfferHistory.php"
backup_file "app/Http/Controllers/OffersController.php"
backup_file "resources/views/layouts/navigation.blade.php"
backup_file "resources/views/offers/index.blade.php"
backup_file "resources/views/offers/create.blade.php"
backup_file "resources/views/offers/edit.blade.php"
backup_file "resources/views/offers/history.blade.php"
backup_file "routes/web.php"

mkdir -p resources/views/offers

# ---------------------------------------------------------------------------
# 1) Migrations: supplier_offers + supplier_offer_history
# ---------------------------------------------------------------------------
MIG_TS_BASE="$(date +"%Y_%m_%d_%H%M%S")"
MIG_OFFERS="database/migrations/${MIG_TS_BASE}_000000_create_supplier_offers_table.php"
MIG_HISTORY="database/migrations/${MIG_TS_BASE}_000001_create_supplier_offer_history_table.php"

cat > "$MIG_OFFERS" << 'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('supplier_offers', function (Blueprint $table) {
            $table->id();

            $table->foreignId('country_id')->constrained()->cascadeOnDelete();
            $table->foreignId('network_id')->constrained()->cascadeOnDelete();
            $table->foreignId('network_mnc_id')->constrained('network_mncs')->cascadeOnDelete();

            $table->foreignId('supplier_id')->constrained('suppliers')->cascadeOnDelete();
            $table->foreignId('supplier_connection_id')->constrained('supplier_connections')->cascadeOnDelete();

            $table->decimal('price', 12, 6);

            $table->string('mcc', 3)->nullable();
            $table->string('mnc', 3)->nullable();
            $table->string('mcc_mnc', 6)->nullable()->index();

            $table->string('product_type')->nullable();
            $table->string('known_hops')->nullable();
            $table->string('sender_id_supported')->nullable();
            $table->string('charge_type', 32)->nullable();

            $table->boolean('is_exclusive')->default(false);
            $table->string('route_type')->nullable();

            // Effective date of this price/version
            $table->date('effective_date');

            $table->timestamps();

            // Only one "live" offer per supplier_connection + network_mnc
            $table->unique(
                ['supplier_connection_id', 'network_mnc_id'],
                'supplier_offers_conn_mnc_unique'
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offers');
    }
};
PHP
echo "==> Created migration: $MIG_OFFERS"

cat > "$MIG_HISTORY" << 'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('supplier_offer_history', function (Blueprint $table) {
            $table->id();

            $table->foreignId('supplier_offer_id')
                ->constrained('supplier_offers')
                ->cascadeOnDelete();

            $table->foreignId('supplier_id')->constrained('suppliers')->cascadeOnDelete();
            $table->foreignId('supplier_connection_id')->constrained('supplier_connections')->cascadeOnDelete();
            $table->foreignId('country_id')->constrained()->cascadeOnDelete();
            $table->foreignId('network_id')->constrained()->cascadeOnDelete();
            $table->foreignId('network_mnc_id')->constrained('network_mncs')->cascadeOnDelete();

            $table->decimal('price', 12, 6);

            $table->string('mcc', 3)->nullable();
            $table->string('mnc', 3)->nullable();
            $table->string('mcc_mnc', 6)->nullable()->index();

            $table->string('product_type')->nullable();
            $table->string('known_hops')->nullable();
            $table->string('sender_id_supported')->nullable();
            $table->string('charge_type', 32)->nullable();

            $table->boolean('is_exclusive')->default(false);
            $table->string('route_type')->nullable();

            $table->date('effective_date');

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offer_history');
    }
};
PHP
echo "==> Created migration: $MIG_HISTORY"

# ---------------------------------------------------------------------------
# 2) Models: SupplierOffer + SupplierOfferHistory
# ---------------------------------------------------------------------------
cat > app/Models/SupplierOffer.php << 'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SupplierOffer extends Model
{
    use HasFactory;

    protected $fillable = [
        'country_id',
        'network_id',
        'network_mnc_id',
        'supplier_id',
        'supplier_connection_id',
        'price',
        'mcc',
        'mnc',
        'mcc_mnc',
        'product_type',
        'known_hops',
        'sender_id_supported',
        'charge_type',
        'is_exclusive',
        'route_type',
        'effective_date',
    ];

    protected $casts = [
        'is_exclusive'   => 'boolean',
        'effective_date' => 'date',
        'price'          => 'decimal:6',
    ];

    public function country()
    {
        return $this->belongsTo(Country::class);
    }

    public function network()
    {
        return $this->belongsTo(Network::class);
    }

    public function networkMnc()
    {
        return $this->belongsTo(NetworkMnc::class);
    }

    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }

    public function connection()
    {
        return $this->belongsTo(SupplierConnection::class, 'supplier_connection_id');
    }

    public function history()
    {
        return $this->hasMany(SupplierOfferHistory::class);
    }

    public function latestHistory()
    {
        return $this->hasOne(SupplierOfferHistory::class)->latestOfMany('effective_date');
    }
}
PHP
echo "==> Wrote app/Models/SupplierOffer.php"

cat > app/Models/SupplierOfferHistory.php << 'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SupplierOfferHistory extends Model
{
    use HasFactory;

    protected $table = 'supplier_offer_history';

    protected $fillable = [
        'supplier_offer_id',
        'supplier_id',
        'supplier_connection_id',
        'country_id',
        'network_id',
        'network_mnc_id',
        'price',
        'mcc',
        'mnc',
        'mcc_mnc',
        'product_type',
        'known_hops',
        'sender_id_supported',
        'charge_type',
        'is_exclusive',
        'route_type',
        'effective_date',
    ];

    protected $casts = [
        'is_exclusive'   => 'boolean',
        'effective_date' => 'date',
        'price'          => 'decimal:6',
    ];

    public function offer()
    {
        return $this->belongsTo(SupplierOffer::class, 'supplier_offer_id');
    }

    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }

    public function connection()
    {
        return $this->belongsTo(SupplierConnection::class, 'supplier_connection_id');
    }

    public function country()
    {
        return $this->belongsTo(Country::class);
    }

    public function network()
    {
        return $this->belongsTo(Network::class);
    }

    public function networkMnc()
    {
        return $this->belongsTo(NetworkMnc::class);
    }
}
PHP
echo "==> Wrote app/Models/SupplierOfferHistory.php"

# ---------------------------------------------------------------------------
# 3) OffersController
# ---------------------------------------------------------------------------
cat > app/Http/Controllers/OffersController.php << 'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\Country;
use App\Models\DropdownItem;
use App\Models\Network;
use App\Models\NetworkMnc;
use App\Models\Supplier;
use App\Models\SupplierConnection;
use App\Models\SupplierOffer;
use App\Models\SupplierOfferHistory;
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
            'latestHistory',
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
                    SupplierOfferHistory::create([
                        'supplier_offer_id'      => $existing->id,
                        'supplier_id'            => $existing->supplier_id,
                        'supplier_connection_id' => $existing->supplier_connection_id,
                        'country_id'             => $existing->country_id,
                        'network_id'             => $existing->network_id,
                        'network_mnc_id'         => $existing->network_mnc_id,
                        'price'                  => $existing->price,
                        'mcc'                    => $existing->mcc,
                        'mnc'                    => $existing->mnc,
                        'mcc_mnc'                => $existing->mcc_mnc,
                        'product_type'           => $existing->product_type,
                        'known_hops'             => $existing->known_hops,
                        'sender_id_supported'    => $existing->sender_id_supported,
                        'charge_type'            => $existing->charge_type,
                        'is_exclusive'           => $existing->is_exclusive,
                        'route_type'             => $existing->route_type,
                        'effective_date'         => $existing->effective_date,
                    ]);
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
                SupplierOfferHistory::create([
                    'supplier_offer_id'      => $offer->id,
                    'supplier_id'            => $offer->supplier_id,
                    'supplier_connection_id' => $offer->supplier_connection_id,
                    'country_id'             => $offer->country_id,
                    'network_id'             => $offer->network_id,
                    'network_mnc_id'         => $offer->network_mnc_id,
                    'price'                  => $offer->price,
                    'mcc'                    => $offer->mcc,
                    'mnc'                    => $offer->mnc,
                    'mcc_mnc'                => $offer->mcc_mnc,
                    'product_type'           => $offer->product_type,
                    'known_hops'             => $offer->known_hops,
                    'sender_id_supported'    => $offer->sender_id_supported,
                    'charge_type'            => $offer->charge_type,
                    'is_exclusive'           => $offer->is_exclusive,
                    'route_type'             => $offer->route_type,
                    'effective_date'         => $offer->effective_date,
                ]);
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

        $history = SupplierOfferHistory::where('supplier_offer_id', $offer->id)
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
PHP
echo "==> Wrote app/Http/Controllers/OffersController.php"

# ---------------------------------------------------------------------------
# 4) Views: offers index/create/edit/history
# ---------------------------------------------------------------------------

# INDEX
cat > resources/views/offers/index.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offers
        </h2>
    </x-slot>

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        @if (session('status'))
            <div class="mb-4 text-sm text-green-600">
                {{ session('status') }}
            </div>
        @endif

        <div class="flex items-center justify-between mb-4">
            <h1 class="text-2xl font-semibold text-gray-800">
                Offers
            </h1>
            <a href="{{ route('offers.create') }}"
               class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                + New Offer
            </a>
        </div>

        {{-- Filters --}}
        <form method="GET" action="{{ route('offers.index') }}" class="mb-4 space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
                {{-- Country (typeahead-style label + hidden id) --}}
                <div>
                    <label for="country_label" class="block text-sm font-medium text-gray-700">
                        Country
                    </label>
                    <input
                        type="text"
                        id="country_label"
                        name="country_label"
                        value="{{ old('country_label', $filters['country_label'] ?? '') }}"
                        autocomplete="off"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                        placeholder="Type to search..."
                    />
                    <input type="hidden" name="country_id" id="country_id"
                           value="{{ old('country_id', $filters['country_id'] ?? '') }}">
                    <ul id="country_suggestions"
                        class="mt-1 max-h-40 overflow-auto border border-gray-200 rounded-md bg-white text-sm hidden z-10">
                        @foreach($countries as $country)
                            <li class="px-2 py-1 cursor-pointer hover:bg-blue-50"
                                data-id="{{ $country->id }}"
                                data-label="{{ $country->name }}">
                                {{ $country->name }}
                            </li>
                        @endforeach
                    </ul>
                </div>

                {{-- Network --}}
                <div>
                    <label for="network_id" class="block text-sm font-medium text-gray-700">
                        Network
                    </label>
                    <select id="network_id" name="network_id"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($networkOptions as $network)
                            <option value="{{ $network->id }}"
                                @selected(($filters['network_id'] ?? null) == $network->id)>
                                {{ $network->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- MNC --}}
                <div>
                    <label for="network_mnc_id" class="block text-sm font-medium text-gray-700">
                        MNC
                    </label>
                    <select id="network_mnc_id" name="network_mnc_id"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($networkMncOptions as $mnc)
                            <option value="{{ $mnc->id }}"
                                @selected(($filters['network_mnc_id'] ?? null) == $mnc->id)>
                                {{ $mnc->mnc }} ({{ $mnc->mcc_mnc }})
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- MCCMNC (text filter) --}}
                <div>
                    <label for="mccmnc" class="block text-sm font-medium text-gray-700">
                        MCCMNC
                    </label>
                    <input
                        type="text"
                        id="mccmnc"
                        name="mccmnc"
                        value="{{ old('mccmnc', $filters['mccmnc'] ?? '') }}"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                        placeholder="e.g. 20201"
                    />
                </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
                {{-- Supplier (typeahead) --}}
                <div>
                    <label for="supplier_label" class="block text-sm font-medium text-gray-700">
                        Supplier
                    </label>
                    <input
                        type="text"
                        id="supplier_label"
                        name="supplier_label"
                        value="{{ old('supplier_label', $filters['supplier_label'] ?? '') }}"
                        autocomplete="off"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                        placeholder="Type to search..."
                    />
                    <input type="hidden" name="supplier_id" id="supplier_id"
                           value="{{ old('supplier_id', $filters['supplier_id'] ?? '') }}">
                    <ul id="supplier_suggestions"
                        class="mt-1 max-h-40 overflow-auto border border-gray-200 rounded-md bg-white text-sm hidden z-10">
                        @foreach($suppliers as $supplier)
                            <li class="px-2 py-1 cursor-pointer hover:bg-blue-50"
                                data-id="{{ $supplier->id }}"
                                data-label="{{ $supplier->name }}">
                                {{ $supplier->name }}
                            </li>
                        @endforeach
                    </ul>
                </div>

                {{-- Connection --}}
                <div>
                    <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">
                        Connection
                    </label>
                    <select id="supplier_connection_id" name="supplier_connection_id"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($connectionOptions as $conn)
                            <option value="{{ $conn->id }}"
                                @selected(($filters['supplier_connection_id'] ?? null) == $conn->id)>
                                {{ $conn->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Product Type --}}
                <div>
                    <label for="product_type" class="block text-sm font-medium text-gray-700">
                        Product Type
                    </label>
                    <select id="product_type" name="product_type"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($productTypeOptions as $value => $label)
                            <option value="{{ $value }}"
                                @selected(($filters['product_type'] ?? null) === $value)>
                                {{ $label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Known Hops --}}
                <div>
                    <label for="known_hops" class="block text-sm font-medium text-gray-700">
                        Known Hops
                    </label>
                    <select id="known_hops" name="known_hops"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($knownHopsOptions as $value => $label)
                            <option value="{{ $value }}"
                                @selected(($filters['known_hops'] ?? null) === $value)>
                                {{ $label }}
                            </option>
                        @endforeach
                    </select>
                </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
                {{-- Sender Id Supported --}}
                <div>
                    <label for="sender_id_supported" class="block text-sm font-medium text-gray-700">
                        Sender Id Supported
                    </label>
                    <select id="sender_id_supported" name="sender_id_supported"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        @foreach($senderIdOptions as $value => $label)
                            <option value="{{ $value }}"
                                @selected(($filters['sender_id_supported'] ?? null) === $value)>
                                {{ $label }}
                            </option>
                        @endforeach
                    </select>
                </div>

                {{-- Charge Type --}}
                <div>
                    <label for="charge_type" class="block text-sm font-medium text-gray-700">
                        Charge Type
                    </label>
                    <select id="charge_type" name="charge_type"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        <option value="per_submit" @selected(($filters['charge_type'] ?? null) === 'per_submit')>
                            Per Submit
                        </option>
                        <option value="per_delivered" @selected(($filters['charge_type'] ?? null) === 'per_delivered')>
                            Per Delivered
                        </option>
                    </select>
                </div>

                {{-- Is Exclusive --}}
                <div>
                    <label for="is_exclusive" class="block text-sm font-medium text-gray-700">
                        Is Exclusive
                    </label>
                    <select id="is_exclusive" name="is_exclusive"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <option value="">-- Any --</option>
                        <option value="1" @selected(($filters['is_exclusive'] ?? null) === '1')>Yes</option>
                        <option value="0" @selected(($filters['is_exclusive'] ?? null) === '0')>No</option>
                    </select>
                </div>

                {{-- Results per page --}}
                <div>
                    <label for="per_page" class="block text-sm font-medium text-gray-700">
                        Results per page
                    </label>
                    <select id="per_page" name="per_page"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        @foreach([25,50,100,200] as $option)
                            <option value="{{ $option }}" @selected($perPage == $option)>
                                {{ $option }}
                            </option>
                        @endforeach
                    </select>
                </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
                {{-- Price range --}}
                <div>
                    <label class="block text-sm font-medium text-gray-700">
                        Price min / max
                    </label>
                    <div class="mt-1 flex space-x-2">
                        <input type="text" name="price_min" id="price_min"
                               value="{{ old('price_min', $filters['price_min'] ?? '') }}"
                               class="block w-1/2 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                               placeholder="Min">
                        <input type="text" name="price_max" id="price_max"
                               value="{{ old('price_max', $filters['price_max'] ?? '') }}"
                               class="block w-1/2 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                               placeholder="Max">
                    </div>
                </div>

                {{-- Effective date range --}}
                <div>
                    <label class="block text-sm font-medium text-gray-700">
                        Effective date from / to
                    </label>
                    <div class="mt-1 flex space-x-2">
                        <input type="date" name="effective_from" id="effective_from"
                               value="{{ old('effective_from', $filters['effective_from'] ?? '') }}"
                               class="block w-1/2 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        <input type="date" name="effective_to" id="effective_to"
                               value="{{ old('effective_to', $filters['effective_to'] ?? '') }}"
                               class="block w-1/2 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                    </div>
                </div>
            </div>

            <div class="mt-3 flex space-x-2 justify-end">
                <button type="submit"
                        class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                    Apply filters
                </button>
                <a href="{{ route('offers.index') }}"
                   class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                    Reset
                </a>
            </div>
        </form>

        {{-- Bulk update + table --}}
        <form method="POST" action="{{ route('offers.bulk-update') }}">
            @csrf

            <div class="bg-white shadow-sm rounded-lg overflow-hidden">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                    <thead class="bg-gray-50">
                        <tr>
                            <th class="px-3 py-2">
                                <input type="checkbox" id="select_all_offers"
                                       class="h-4 w-4 text-blue-600 border-gray-300 rounded">
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Country
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Network
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                MCCMNC
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Supplier
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Connection
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Username
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Product Type
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Known Hops
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Sender Id Supported
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Price
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Charge Type
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Is Exclusive
                            </th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Effective Date
                            </th>
                            <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Actions
                            </th>
                        </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                        @forelse($offers as $offer)
                            @php
                                $prev = $offer->latestHistory;
                            @endphp
                            <tr>
                                <td class="px-3 py-2 whitespace-nowrap">
                                    <input type="checkbox"
                                           name="offer_ids[]"
                                           value="{{ $offer->id }}"
                                           class="offer_checkbox h-4 w-4 text-blue-600 border-gray-300 rounded">
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->country?->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->network?->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->mcc_mnc }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->supplier?->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->connection?->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->connection?->username }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->product_type }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->known_hops }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $offer->sender_id_supported }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    <a href="{{ route('offers.history', $offer) }}"
                                       target="_blank"
                                       class="text-indigo-600 hover:text-indigo-900"
                                       @if($prev)
                                           title="Previous: {{ $prev->price }} ({{ $prev->effective_date?->format('Y-m-d') }})"
                                       @endif
                                    >
                                        {{ number_format((float) $offer->price, 6) }}
                                    </a>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    @if($offer->charge_type === 'per_submit')
                                        Per Submit
                                    @elseif($offer->charge_type === 'per_delivered')
                                        Per Delivered
                                    @else
                                        {{ $offer->charge_type }}
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    @if($offer->is_exclusive)
                                        <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-green-50 text-green-700 text-xs">
                                            Yes
                                        </span>
                                    @else
                                        <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-gray-50 text-gray-500 text-xs">
                                            No
                                        </span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    <a href="{{ route('offers.history', $offer) }}"
                                       target="_blank"
                                       class="text-indigo-600 hover:text-indigo-900"
                                       @if($prev)
                                           title="Previous: {{ $prev->price }} ({{ $prev->effective_date?->format('Y-m-d') }})"
                                       @endif
                                    >
                                        {{ $offer->effective_date?->format('Y-m-d') }}
                                    </a>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-right text-sm">
                                    <a href="{{ route('offers.edit', $offer) }}"
                                       class="text-blue-600 hover:text-blue-900">
                                        Edit
                                    </a>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="15" class="px-4 py-4 text-center text-sm text-gray-500">
                                    No offers found.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div class="mt-4">
                {{ $offers->links() }}
            </div>

            {{-- Bulk update panel --}}
            <div class="mt-6 bg-white shadow-sm rounded-lg p-4">
                <h3 class="text-sm font-semibold text-gray-800 mb-3">
                    Bulk update selected offers
                </h3>
                <div class="grid grid-cols-1 md:grid-cols-5 gap-3">
                    <div>
                        <label for="bulk_route_type" class="block text-xs font-medium text-gray-700">
                            Route Type
                        </label>
                        <input type="text" id="bulk_route_type" name="bulk_route_type"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-xs"
                               placeholder="Leave blank = no change">
                    </div>

                    <div>
                        <label for="bulk_known_hops" class="block text-xs font-medium text-gray-700">
                            Known Hops
                        </label>
                        <select id="bulk_known_hops" name="bulk_known_hops"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-xs">
                            <option value="">(no change)</option>
                            @foreach($knownHopsOptions as $value => $label)
                                <option value="{{ $value }}">{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label for="bulk_sender_id_supported" class="block text-xs font-medium text-gray-700">
                            Sender Id Supported
                        </label>
                        <select id="bulk_sender_id_supported" name="bulk_sender_id_supported"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-xs">
                            <option value="">(no change)</option>
                            @foreach($senderIdOptions as $value => $label)
                                <option value="{{ $value }}">{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label for="bulk_charge_type" class="block text-xs font-medium text-gray-700">
                            Charge Model
                        </label>
                        <select id="bulk_charge_type" name="bulk_charge_type"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-xs">
                            <option value="">(no change)</option>
                            <option value="per_submit">Per Submit</option>
                            <option value="per_delivered">Per Delivered</option>
                        </select>
                    </div>

                    <div>
                        <label for="bulk_is_exclusive" class="block text-xs font-medium text-gray-700">
                            Is Exclusive
                        </label>
                        <select id="bulk_is_exclusive" name="bulk_is_exclusive"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-xs">
                            <option value="">(no change)</option>
                            <option value="1">Set: Yes</option>
                            <option value="0">Set: No</option>
                        </select>
                    </div>
                </div>

                <div class="mt-3 flex justify-end">
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-indigo-600 text-white hover:bg-indigo-700">
                        Apply to selected
                    </button>
                </div>
            </div>
        </form>
    </div>

    {{-- Simple JS for country/supplier suggestions + select-all --}}
    <script>
        (function () {
            function setupTypeahead(inputId, hiddenId, listId) {
                const input = document.getElementById(inputId);
                const hidden = document.getElementById(hiddenId);
                const list = document.getElementById(listId);
                if (!input || !hidden || !list) return;

                let items = Array.from(list.querySelectorAll('li'));
                let currentIndex = -1;

                function closeList() {
                    list.classList.add('hidden');
                    currentIndex = -1;
                    items.forEach(li => li.classList.remove('bg-blue-100'));
                }

                function openList() {
                    list.classList.remove('hidden');
                }

                function highlight(index) {
                    items.forEach((li, i) => {
                        li.classList.toggle('bg-blue-100', i === index);
                    });
                }

                input.addEventListener('input', function () {
                    const val = this.value.toLowerCase();
                    items.forEach(li => {
                        const label = (li.dataset.label || '').toLowerCase();
                        li.style.display = label.includes(val) ? '' : 'none';
                    });
                    openList();
                });

                input.addEventListener('keydown', function (e) {
                    if (e.key === 'ArrowDown') {
                        e.preventDefault();
                        openList();
                        const visible = items.filter(li => li.style.display !== 'none');
                        if (!visible.length) return;
                        if (currentIndex < visible.length - 1) {
                            currentIndex++;
                        }
                        highlightIndexInVisible(visible);
                    } else if (e.key === 'ArrowUp') {
                        e.preventDefault();
                        const visible = items.filter(li => li.style.display !== 'none');
                        if (!visible.length) return;
                        if (currentIndex > 0) {
                            currentIndex--;
                        }
                        highlightIndexInVisible(visible);
                    } else if (e.key === 'Enter') {
                        const visible = items.filter(li => li.style.display !== 'none');
                        if (currentIndex >= 0 && currentIndex < visible.length) {
                            e.preventDefault();
                            selectItem(visible[currentIndex]);
                        }
                    } else if (e.key === 'Escape') {
                        closeList();
                    }
                });

                function highlightIndexInVisible(visible) {
                    items.forEach(li => li.classList.remove('bg-blue-100'));
                    if (currentIndex >= 0 && currentIndex < visible.length) {
                        const li = visible[currentIndex];
                        li.classList.add('bg-blue-100');
                    }
                }

                function selectItem(li) {
                    input.value = li.dataset.label || '';
                    hidden.value = li.dataset.id || '';
                    closeList();
                }

                items.forEach(li => {
                    li.addEventListener('mousedown', function (e) {
                        e.preventDefault();
                        selectItem(li);
                    });
                });

                document.addEventListener('click', function (e) {
                    if (!list.contains(e.target) && e.target !== input) {
                        closeList();
                    }
                });
            }

            setupTypeahead('country_label', 'country_id', 'country_suggestions');
            setupTypeahead('supplier_label', 'supplier_id', 'supplier_suggestions');

            const selectAll = document.getElementById('select_all_offers');
            if (selectAll) {
                selectAll.addEventListener('change', function () {
                    document.querySelectorAll('.offer_checkbox').forEach(cb => {
                        cb.checked = selectAll.checked;
                    });
                });
            }
        })();
    </script>
</x-app-layout>
BLADE
echo "==> Wrote resources/views/offers/index.blade.php"

# CREATE VIEW
cat > resources/views/offers/create.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            New Offer
        </h2>
    </x-slot>

    <div class="py-6 max-w-5xl mx-auto sm:px-6 lg:px-8">
        <div class="bg-white shadow-sm rounded-lg p-6">
            <form method="POST" action="{{ route('offers.store') }}" class="space-y-6">
                @csrf

                {{-- Country / Network / MNC --}}
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label for="country_id" class="block text-sm font-medium text-gray-700">
                            Country
                        </label>
                        <select id="country_id" name="country_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($countries as $country)
                                <option value="{{ $country->id }}" @selected(old('country_id') == $country->id)>
                                    {{ $country->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('country_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="network_id" class="block text-sm font-medium text-gray-700">
                            Network
                        </label>
                        <select id="network_id" name="network_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($networks as $network)
                                <option value="{{ $network->id }}" data-country-id="{{ $network->country_id }}"
                                    @selected(old('network_id') == $network->id)>
                                    {{ $network->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('network_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="network_mnc_id" class="block text-sm font-medium text-gray-700">
                            MNC
                        </label>
                        <select id="network_mnc_id" name="network_mnc_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($networkMncs as $mnc)
                                <option value="{{ $mnc->id }}" data-network-id="{{ $mnc->network_id }}"
                                        data-mcc="{{ $mnc->mcc }}" data-mnc="{{ $mnc->mnc }}" data-mccmnc="{{ $mnc->mcc_mnc }}"
                                        @selected(old('network_mnc_id') == $mnc->id)>
                                    {{ $mnc->mnc }} ({{ $mnc->mcc_mnc }})
                                </option>
                            @endforeach
                        </select>
                        @error('network_mnc_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                {{-- MCCMNC readonly --}}
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label for="mccmnc_display" class="block text-sm font-medium text-gray-700">
                            MCCMNC
                        </label>
                        <input type="text" id="mccmnc_display" readonly
                               class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm text-sm"
                               value="">
                    </div>

                    <div>
                        <label for="price" class="block text-sm font-medium text-gray-700">
                            Price
                        </label>
                        <input type="text" id="price" name="price"
                               value="{{ old('price') }}"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                               placeholder="e.g. 0.012345">
                        @error('price')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="effective_date" class="block text-sm font-medium text-gray-700">
                            Effective Date
                        </label>
                        <input type="date" id="effective_date" name="effective_date"
                               value="{{ old('effective_date') }}"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                        @error('effective_date')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                {{-- Supplier / Connection / Username --}}
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label for="supplier_id" class="block text-sm font-medium text-gray-700">
                            Supplier
                        </label>
                        <select id="supplier_id" name="supplier_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($suppliers as $supplier)
                                <option value="{{ $supplier->id }}" @selected(old('supplier_id') == $supplier->id)>
                                    {{ $supplier->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('supplier_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">
                            Connection
                        </label>
                        <select id="supplier_connection_id" name="supplier_connection_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($connections as $conn)
                                <option value="{{ $conn->id }}"
                                        data-supplier-id="{{ $conn->supplier_id }}"
                                        data-username="{{ $conn->username }}"
                                        data-product-type="{{ $conn->product_type }}"
                                        data-charge-type="{{ $conn->charge_type }}"
                                        @selected(old('supplier_connection_id') == $conn->id)>
                                    {{ $conn->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('supplier_connection_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="username_display" class="block text-sm font-medium text-gray-700">
                            Username
                        </label>
                        <input type="text" id="username_display" readonly
                               class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm text-sm"
                               value="">
                    </div>
                </div>

                {{-- Product Type / Known Hops / Sender Id / Charge Type --}}
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                    <div>
                        <label for="product_type" class="block text-sm font-medium text-gray-700">
                            Product Type
                        </label>
                        <select id="product_type" name="product_type"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select (or default from connection) --</option>
                            @foreach($productTypeOptions as $value => $label)
                                <option value="{{ $value }}" @selected(old('product_type') == $value)>
                                    {{ $label }}
                                </option>
                            @endforeach
                        </select>
                        @error('product_type')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="known_hops" class="block text-sm font-medium text-gray-700">
                            Known Hops
                        </label>
                        <select id="known_hops" name="known_hops"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($knownHopsOptions as $value => $label)
                                <option value="{{ $value }}" @selected(old('known_hops') == $value)>
                                    {{ $label }}
                                </option>
                            @endforeach
                        </select>
                        @error('known_hops')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="sender_id_supported" class="block text-sm font-medium text-gray-700">
                            Sender Id Supported
                        </label>
                        <select id="sender_id_supported" name="sender_id_supported"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($senderIdOptions as $value => $label)
                                <option value="{{ $value }}" @selected(old('sender_id_supported') == $value)>
                                    {{ $label }}
                                </option>
                            @endforeach
                        </select>
                        @error('sender_id_supported')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="charge_type" class="block text-sm font-medium text-gray-700">
                            Charge Type
                        </label>
                        <select id="charge_type" name="charge_type"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select (or default from connection) --</option>
                            <option value="per_submit" @selected(old('charge_type') === 'per_submit')>
                                Per Submit
                            </option>
                            <option value="per_delivered" @selected(old('charge_type') === 'per_delivered')>
                                Per Delivered
                            </option>
                        </select>
                        @error('charge_type')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                {{-- Route Type / Is Exclusive --}}
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                    <div>
                        <label for="route_type" class="block text-sm font-medium text-gray-700">
                            Route Type
                        </label>
                        <input type="text" id="route_type" name="route_type"
                               value="{{ old('route_type') }}"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                               placeholder="Optional">
                        @error('route_type')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div class="flex items-center mt-6">
                        <input type="checkbox" id="is_exclusive" name="is_exclusive" value="1"
                               class="h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
                               @checked(old('is_exclusive'))>
                        <label for="is_exclusive" class="ml-2 text-sm text-gray-700">
                            Is Exclusive
                        </label>
                    </div>
                </div>

                <div class="flex justify-end space-x-2">
                    <a href="{{ route('offers.index') }}"
                       class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md text-sm text-gray-700 bg-white hover:bg-gray-50">
                        Cancel
                    </a>
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700">
                        Save Offer
                    </button>
                </div>
            </form>
        </div>
    </div>

    <script>
        (function () {
            const countrySelect = document.getElementById('country_id');
            const networkSelect = document.getElementById('network_id');
            const mncSelect = document.getElementById('network_mnc_id');
            const mccmncDisplay = document.getElementById('mccmnc_display');
            const supplierSelect = document.getElementById('supplier_id');
            const connSelect = document.getElementById('supplier_connection_id');
            const usernameDisplay = document.getElementById('username_display');
            const productTypeSelect = document.getElementById('product_type');
            const chargeTypeSelect = document.getElementById('charge_type');

            function filterNetworksByCountry() {
                const countryId = countrySelect.value;
                Array.from(networkSelect.options).forEach(opt => {
                    if (!opt.value) return;
                    const cid = opt.getAttribute('data-country-id');
                    opt.hidden = !!countryId && cid !== countryId;
                });
            }

            function filterMncsByNetwork() {
                const networkId = networkSelect.value;
                Array.from(mncSelect.options).forEach(opt => {
                    if (!opt.value) return;
                    const nid = opt.getAttribute('data-network-id');
                    opt.hidden = !!networkId && nid !== networkId;
                });
            }

            function updateMccMncDisplay() {
                const opt = mncSelect.selectedOptions[0];
                if (opt && opt.value) {
                    const mccmnc = opt.getAttribute('data-mccmnc') || '';
                    mccmncDisplay.value = mccmnc;
                } else {
                    mccmncDisplay.value = '';
                }
            }

            function filterConnectionsBySupplier() {
                const supplierId = supplierSelect.value;
                Array.from(connSelect.options).forEach(opt => {
                    if (!opt.value) return;
                    const sid = opt.getAttribute('data-supplier-id');
                    opt.hidden = !!supplierId && sid !== supplierId;
                });
                updateConnectionDependentFields();
            }

            function updateConnectionDependentFields() {
                const opt = connSelect.selectedOptions[0];
                if (opt && opt.value) {
                    const username = opt.getAttribute('data-username') || '';
                    const productType = opt.getAttribute('data-product-type') || '';
                    const chargeType = opt.getAttribute('data-charge-type') || '';

                    usernameDisplay.value = username;

                    if (!productTypeSelect.value && productType) {
                        productTypeSelect.value = productType;
                    }
                    if (!chargeTypeSelect.value && chargeType) {
                        chargeTypeSelect.value = chargeType;
                    }
                } else {
                    usernameDisplay.value = '';
                }
            }

            if (countrySelect && networkSelect && mncSelect) {
                countrySelect.addEventListener('change', function () {
                    filterNetworksByCountry();
                    filterMncsByNetwork();
                    updateMccMncDisplay();
                });
                networkSelect.addEventListener('change', function () {
                    filterMncsByNetwork();
                    updateMccMncDisplay();
                });
                mncSelect.addEventListener('change', updateMccMncDisplay);
                filterNetworksByCountry();
                filterMncsByNetwork();
                updateMccMncDisplay();
            }

            if (supplierSelect && connSelect && usernameDisplay) {
                supplierSelect.addEventListener('change', function () {
                    filterConnectionsBySupplier();
                });
                connSelect.addEventListener('change', updateConnectionDependentFields);
                filterConnectionsBySupplier();
            }
        })();
    </script>
</x-app-layout>
BLADE
echo "==> Wrote resources/views/offers/create.blade.php"

# EDIT VIEW
cat > resources/views/offers/edit.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Edit Offer
        </h2>
    </x-slot>

    <div class="py-6 max-w-5xl mx-auto sm:px-6 lg:px-8">
        <div class="bg-white shadow-sm rounded-lg p-6">
            <form method="POST" action="{{ route('offers.update', $offer) }}" class="space-y-6">
                @csrf
                @method('PUT')

                {{-- Country / Network / MNC --}}
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label for="country_id" class="block text-sm font-medium text-gray-700">
                            Country
                        </label>
                        <select id="country_id" name="country_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($countries as $country)
                                <option value="{{ $country->id }}"
                                    @selected(old('country_id', $offer->country_id) == $country->id)>
                                    {{ $country->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('country_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="network_id" class="block text-sm font-medium text-gray-700">
                            Network
                        </label>
                        <select id="network_id" name="network_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($networks as $network)
                                <option value="{{ $network->id }}"
                                        data-country-id="{{ $network->country_id }}"
                                    @selected(old('network_id', $offer->network_id) == $network->id)>
                                    {{ $network->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('network_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="network_mnc_id" class="block text-sm font-medium text-gray-700">
                            MNC
                        </label>
                        <select id="network_mnc_id" name="network_mnc_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($networkMncs as $mnc)
                                <option value="{{ $mnc->id }}"
                                        data-network-id="{{ $mnc->network_id }}"
                                        data-mcc="{{ $mnc->mcc }}"
                                        data-mnc="{{ $mnc->mnc }}"
                                        data-mccmnc="{{ $mnc->mcc_mnc }}"
                                    @selected(old('network_mnc_id', $offer->network_mnc_id) == $mnc->id)>
                                    {{ $mnc->mnc }} ({{ $mnc->mcc_mnc }})
                                </option>
                            @endforeach
                        </select>
                        @error('network_mnc_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                {{-- MCCMNC readonly / Price / Effective --}}
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label for="mccmnc_display" class="block text-sm font-medium text-gray-700">
                            MCCMNC
                        </label>
                        <input type="text" id="mccmnc_display" readonly
                               class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm text-sm"
                               value="{{ $offer->mcc_mnc }}">
                    </div>

                    <div>
                        <label for="price" class="block text-sm font-medium text-gray-700">
                            Price
                        </label>
                        <input type="text" id="price" name="price"
                               value="{{ old('price', $offer->price) }}"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                        @error('price')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="effective_date" class="block text-sm font-medium text-gray-700">
                            Effective Date
                        </label>
                        <input type="date" id="effective_date" name="effective_date"
                               value="{{ old('effective_date', optional($offer->effective_date)->format('Y-m-d')) }}"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                        @error('effective_date')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                {{-- Supplier / Connection / Username --}}
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label for="supplier_id" class="block text-sm font-medium text-gray-700">
                            Supplier
                        </label>
                        <select id="supplier_id" name="supplier_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($suppliers as $supplier)
                                <option value="{{ $supplier->id }}"
                                    @selected(old('supplier_id', $offer->supplier_id) == $supplier->id)>
                                    {{ $supplier->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('supplier_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="supplier_connection_id" class="block text-sm font-medium text-gray-700">
                            Connection
                        </label>
                        <select id="supplier_connection_id" name="supplier_connection_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($connections as $conn)
                                <option value="{{ $conn->id }}"
                                        data-supplier-id="{{ $conn->supplier_id }}"
                                        data-username="{{ $conn->username }}"
                                        data-product-type="{{ $conn->product_type }}"
                                        data-charge-type="{{ $conn->charge_type }}"
                                    @selected(old('supplier_connection_id', $offer->supplier_connection_id) == $conn->id)>
                                    {{ $conn->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('supplier_connection_id')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="username_display" class="block text-sm font-medium text-gray-700">
                            Username
                        </label>
                        <input type="text" id="username_display" readonly
                               class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm text-sm"
                               value="{{ $offer->connection?->username }}">
                    </div>
                </div>

                {{-- Product Type / Known Hops / Sender Id / Charge Type --}}
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                    <div>
                        <label for="product_type" class="block text-sm font-medium text-gray-700">
                            Product Type
                        </label>
                        <select id="product_type" name="product_type"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($productTypeOptions as $value => $label)
                                <option value="{{ $value }}"
                                    @selected(old('product_type', $offer->product_type) == $value)>
                                    {{ $label }}
                                </option>
                            @endforeach
                        </select>
                        @error('product_type')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="known_hops" class="block text-sm font-medium text-gray-700">
                            Known Hops
                        </label>
                        <select id="known_hops" name="known_hops"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($knownHopsOptions as $value => $label)
                                <option value="{{ $value }}"
                                    @selected(old('known_hops', $offer->known_hops) == $value)>
                                    {{ $label }}
                                </option>
                            @endforeach
                        </select>
                        @error('known_hops')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="sender_id_supported" class="block text-sm font-medium text-gray-700">
                            Sender Id Supported
                        </label>
                        <select id="sender_id_supported" name="sender_id_supported"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            @foreach($senderIdOptions as $value => $label)
                                <option value="{{ $value }}"
                                    @selected(old('sender_id_supported', $offer->sender_id_supported) == $value)>
                                    {{ $label }}
                                </option>
                            @endforeach
                        </select>
                        @error('sender_id_supported')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="charge_type" class="block text-sm font-medium text-gray-700">
                            Charge Type
                        </label>
                        <select id="charge_type" name="charge_type"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                            <option value="">-- Select --</option>
                            <option value="per_submit" @selected(old('charge_type', $offer->charge_type) === 'per_submit')>
                                Per Submit
                            </option>
                            <option value="per_delivered" @selected(old('charge_type', $offer->charge_type) === 'per_delivered')>
                                Per Delivered
                            </option>
                        </select>
                        @error('charge_type')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                {{-- Route Type / Is Exclusive --}}
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                    <div>
                        <label for="route_type" class="block text-sm font-medium text-gray-700">
                            Route Type
                        </label>
                        <input type="text" id="route_type" name="route_type"
                               value="{{ old('route_type', $offer->route_type) }}"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
                        @error('route_type')
                        <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div class="flex items-center mt-6">
                        <input type="checkbox" id="is_exclusive" name="is_exclusive" value="1"
                               class="h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
                               @checked(old('is_exclusive', $offer->is_exclusive))>
                        <label for="is_exclusive" class="ml-2 text-sm text-gray-700">
                            Is Exclusive
                        </label>
                    </div>
                </div>

                <div class="flex justify-between">
                    <form method="POST" action="{{ route('offers.destroy', $offer) }}"
                          onsubmit="return confirm('Delete this offer?');">
                        @csrf
                        @method('DELETE')
                        <button type="submit"
                                class="inline-flex items-center px-4 py-2 border border-red-300 rounded-md text-sm text-red-700 bg-white hover:bg-red-50">
                            Delete
                        </button>
                    </form>

                    <div class="flex space-x-2">
                        <a href="{{ route('offers.index') }}"
                           class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md text-sm text-gray-700 bg-white hover:bg-gray-50">
                            Cancel
                        </a>
                        <button type="submit"
                                class="inline-flex items-center px-4 py-2 border border-transparent rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700">
                            Update Offer
                        </button>
                    </div>
                </div>
            </form>
        </div>
    </div>

    <script>
        (function () {
            const countrySelect = document.getElementById('country_id');
            const networkSelect = document.getElementById('network_id');
            const mncSelect = document.getElementById('network_mnc_id');
            const mccmncDisplay = document.getElementById('mccmnc_display');
            const supplierSelect = document.getElementById('supplier_id');
            const connSelect = document.getElementById('supplier_connection_id');
            const usernameDisplay = document.getElementById('username_display');

            function filterNetworksByCountry() {
                const countryId = countrySelect.value;
                Array.from(networkSelect.options).forEach(opt => {
                    if (!opt.value) return;
                    const cid = opt.getAttribute('data-country-id');
                    opt.hidden = !!countryId && cid !== countryId;
                });
            }

            function filterMncsByNetwork() {
                const networkId = networkSelect.value;
                Array.from(mncSelect.options).forEach(opt => {
                    if (!opt.value) return;
                    const nid = opt.getAttribute('data-network-id');
                    opt.hidden = !!networkId && nid !== networkId;
                });
            }

            function updateMccMncDisplay() {
                const opt = mncSelect.selectedOptions[0];
                if (opt && opt.value) {
                    mccmncDisplay.value = opt.getAttribute('data-mccmnc') || '';
                } else {
                    mccmncDisplay.value = '';
                }
            }

            function filterConnectionsBySupplier() {
                const supplierId = supplierSelect.value;
                Array.from(connSelect.options).forEach(opt => {
                    if (!opt.value) return;
                    const sid = opt.getAttribute('data-supplier-id');
                    opt.hidden = !!supplierId && sid !== supplierId;
                });
                updateConnectionDependentFields();
            }

            function updateConnectionDependentFields() {
                const opt = connSelect.selectedOptions[0];
                if (opt && opt.value) {
                    usernameDisplay.value = opt.getAttribute('data-username') || '';
                } else {
                    usernameDisplay.value = '';
                }
            }

            if (countrySelect && networkSelect && mncSelect) {
                countrySelect.addEventListener('change', function () {
                    filterNetworksByCountry();
                    filterMncsByNetwork();
                    updateMccMncDisplay();
                });
                networkSelect.addEventListener('change', function () {
                    filterMncsByNetwork();
                    updateMccMncDisplay();
                });
                mncSelect.addEventListener('change', updateMccMncDisplay);
                filterNetworksByCountry();
                filterMncsByNetwork();
                updateMccMncDisplay();
            }

            if (supplierSelect && connSelect && usernameDisplay) {
                supplierSelect.addEventListener('change', function () {
                    filterConnectionsBySupplier();
                });
                connSelect.addEventListener('change', updateConnectionDependentFields);
                filterConnectionsBySupplier();
            }
        })();
    </script>
</x-app-layout>
BLADE
echo "==> Wrote resources/views/offers/edit.blade.php"

# HISTORY VIEW
cat > resources/views/offers/history.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offer History
        </h2>
    </x-slot>

    <div class="py-6 max-w-5xl mx-auto sm:px-6 lg:px-8">
        <div class="mb-4 bg-white shadow-sm rounded-lg p-4 text-sm">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
                <div>
                    <div class="text-gray-500">Supplier</div>
                    <div class="text-gray-900 font-medium">{{ $offer->supplier?->name }}</div>
                </div>
                <div>
                    <div class="text-gray-500">Connection</div>
                    <div class="text-gray-900 font-medium">{{ $offer->connection?->name }}</div>
                </div>
                <div>
                    <div class="text-gray-500">Country / Network</div>
                    <div class="text-gray-900">
                        {{ $offer->country?->name }} — {{ $offer->network?->name }}
                    </div>
                </div>
                <div>
                    <div class="text-gray-500">MCCMNC</div>
                    <div class="text-gray-900">{{ $offer->mcc_mnc }}</div>
                </div>
            </div>
        </div>

        <div class="bg-white shadow-sm rounded-lg overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Price
                        </th>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Effective Date
                        </th>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Product Type
                        </th>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Charge Type
                        </th>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Is Exclusive
                        </th>
                    </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                    @forelse($history as $row)
                        <tr>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                {{ number_format((float) $row->price, 6) }}
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                {{ $row->effective_date?->format('Y-m-d') }}
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                {{ $row->product_type }}
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                @if($row->charge_type === 'per_submit')
                                    Per Submit
                                @elseif($row->charge_type === 'per_delivered')
                                    Per Delivered
                                @else
                                    {{ $row->charge_type }}
                                @endif
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                @if($row->is_exclusive)
                                    Yes
                                @else
                                    No
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="px-4 py-4 text-center text-sm text-gray-500">
                                No historic prices recorded for this offer yet.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div class="mt-4">
            <a href="{{ route('offers.index') }}"
               class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md text-sm text-gray-700 bg-white hover:bg-gray-50">
                Back to Offers
            </a>
        </div>
    </div>
</x-app-layout>
BLADE
echo "==> Wrote resources/views/offers/history.blade.php"

# ---------------------------------------------------------------------------
# 5) Routes: append Offers routes (auth-protected)
# ---------------------------------------------------------------------------
cat >> routes/web.php << 'PHP'

Route::middleware(['auth'])->group(function () {
    Route::get('/offers', [\App\Http\Controllers\OffersController::class, 'index'])->name('offers.index');
    Route::get('/offers/create', [\App\Http\Controllers\OffersController::class, 'create'])->name('offers.create');
    Route::post('/offers', [\App\Http\Controllers\OffersController::class, 'store'])->name('offers.store');
    Route::get('/offers/{offer}/edit', [\App\Http\Controllers\OffersController::class, 'edit'])->name('offers.edit');
    Route::put('/offers/{offer}', [\App\Http\Controllers\OffersController::class, 'update'])->name('offers.update');
    Route::delete('/offers/{offer}', [\App\Http\Controllers\OffersController::class, 'destroy'])->name('offers.destroy');

    Route::get('/offers/{offer}/history', [\App\Http\Controllers\OffersController::class, 'history'])->name('offers.history');
    Route::post('/offers/bulk-update', [\App\Http\Controllers\OffersController::class, 'bulkUpdate'])->name('offers.bulk-update');
});
PHP
echo "==> Appended Offers routes to routes/web.php"

# ---------------------------------------------------------------------------
# 6) Navigation: insert Offers after Dashboard in main + mobile nav
# ---------------------------------------------------------------------------
NAV_FILE="resources/views/layouts/navigation.blade.php"
if [[ -f "$NAV_FILE" ]]; then
  echo "==> Patching navigation to add Offers link"
  # Desktop nav
  perl -0pi -e '
    s#(<x-nav-link\s*:href="route\('"'dashboard'"'\)"[^>]*>.*?</x-nav-link>)#$1\n                    <x-nav-link :href="route('"'offers.index'"')" :active="request()->routeIs('"'offers.*'"')">\n                        {{ __(""'Offers'"') }}\n                    </x-nav-link>#s
  ' "$NAV_FILE" || true

  # Mobile nav
  perl -0pi -e '
    s#(<x-responsive-nav-link\s*:href="route\('"'dashboard'"'\)"[^>]*>.*?</x-responsive-nav-link>)#$1\n            <x-responsive-nav-link :href="route('"'offers.index'"')" :active="request()->routeIs('"'offers.*'"')">\n                {{ __(""'Offers'"') }}\n            </x-responsive-nav-link>#s
  ' "$NAV_FILE" || true
else
  echo "==> navigation.blade.php not found; skipping nav patch"
fi

# ---------------------------------------------------------------------------
# 7) Run migrations + clear caches in container
# ---------------------------------------------------------------------------
echo "==> Running migrations inside docker 'app' service"
docker compose exec -T app php artisan migrate --force

echo "==> Clearing caches"
docker compose exec -T app php artisan optimize:clear

echo "==> add_offers_module_v1: done"
