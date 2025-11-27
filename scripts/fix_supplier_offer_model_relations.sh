#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_fix_supplier_offer_model_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/app/Models"

if [ -f "app/Models/SupplierOffer.php" ]; then
  cp app/Models/SupplierOffer.php "${BACKUP_DIR}/app/Models/" \
    || echo "WARN: could not backup SupplierOffer.php"
else
  echo "!! app/Models/SupplierOffer.php not found. Aborting."
  exit 1
fi

cat > app/Models/SupplierOffer.php << 'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class SupplierOffer extends Model
{
    use HasFactory;

    protected $table = 'supplier_offers';

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
        'product_type_id',
        'known_hops_dropdown_item_id',
        'sender_id_supported_dropdown_item_id',
        'route_type_id',
        'charge_model_id',
        'charge_type',
        'is_exclusive',
        'effective_date',
        'updated_by',
    ];

    protected $casts = [
        'is_exclusive'   => 'boolean',
        'effective_date' => 'datetime',
    ];

    /**
     * Global scope: αν υπάρχει ?mcc_mnc= στο query string,
     * φιλτράρουμε τα offers με βάση το πεδίο mcc_mnc (case-insensitive).
     */
    protected static function booted(): void
    {
        static::addGlobalScope('mcc_mnc_filter', function (Builder $builder) {
            $req = request();
            if (!$req) {
                return;
            }

            $mccMnc = $req->query('mcc_mnc');
            if ($mccMnc !== null && $mccMnc !== '') {
                $mccMnc = strtolower($mccMnc);
                $builder->whereRaw('LOWER(mcc_mnc) LIKE ?', ['%' . $mccMnc . '%']);
            }
        });
    }

    /** Country */
    public function country()
    {
        return $this->belongsTo(Country::class);
    }

    /** Network */
    public function network()
    {
        return $this->belongsTo(Network::class);
    }

    /** Network MNC */
    public function networkMnc()
    {
        return $this->belongsTo(NetworkMnc::class);
    }

    /** Supplier */
    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }

    /** Connection */
    public function connection()
    {
        return $this->belongsTo(SupplierConnection::class, 'supplier_connection_id');
    }

    /** Product type dropdown (menu_id = 1) */
    public function productTypeDropdown()
    {
        return $this->belongsTo(DropdownItem::class, 'product_type_id');
    }

    /**
     * Known Hops dropdown (menu_id = 2)
     * Όνομα που περιμένει ο controller: knownHopsDropdown
     */
    public function knownHopsDropdown()
    {
        return $this->belongsTo(DropdownItem::class, 'known_hops_dropdown_item_id');
    }

    /** Alias για συμβατότητα (αν χρησιμοποιηθεί αλλού) */
    public function knownHopsDropdownItem()
    {
        return $this->belongsTo(DropdownItem::class, 'known_hops_dropdown_item_id');
    }

    /**
     * Sender ID Supported dropdown (menu_id = 3)
     * Όνομα που περιμένει ο controller: senderIdSupportedDropdown
     */
    public function senderIdSupportedDropdown()
    {
        return $this->belongsTo(DropdownItem::class, 'sender_id_supported_dropdown_item_id');
    }

    /** Alias για συμβατότητα */
    public function senderIdSupportedDropdownItem()
    {
        return $this->belongsTo(DropdownItem::class, 'sender_id_supported_dropdown_item_id');
    }

    /** User που έκανε το τελευταίο edit */
    public function updater()
    {
        return $this->belongsTo(User::class, 'updated_by');
    }
}
PHP

echo "==> SupplierOffer model rewritten successfully."
echo "==> Backup stored at: ${BACKUP_DIR}"
