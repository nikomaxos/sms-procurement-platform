<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

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
     * Global scope: όταν υπάρχει ?mcc_mnc= στο request,
     * φιλτράρουμε με βάση το πεδίο mcc_mnc (case-insensitive).
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
                // portable, δουλεύει και σε Postgres και σε MySQL
                $builder->whereRaw('LOWER(mcc_mnc) LIKE ?', ['%' . $mccMnc . '%']);
            }
        });
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

    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }

    public function connection()
    {
        return $this->belongsTo(SupplierConnection::class, 'supplier_connection_id');
    }

    public function productTypeDropdown()
    {
        return $this->belongsTo(DropdownItem::class, 'product_type_id');
    }

    public function knownHopsDropdownItem()
    {
        return $this->belongsTo(DropdownItem::class, 'known_hops_dropdown_item_id');
    }

    public function senderIdSupportedDropdownItem()
    {
        return $this->belongsTo(DropdownItem::class, 'sender_id_supported_dropdown_item_id');
    }

    public function updater()
    {
        return $this->belongsTo(User::class, 'updated_by');
    }
}
