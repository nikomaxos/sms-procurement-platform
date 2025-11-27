<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;

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
        'effective_date' => 'date',
        'price'          => 'decimal:10',
    ];

    /**
     * Auto-fill updated_by for create & update using current user.
     */
    protected static function booted()
    {
        static::creating(function (self $offer) {
            if (Auth::check()) {
                $offer->updated_by = Auth::id();
            }
        });

        static::updating(function (self $offer) {
            if (Auth::check()) {
                $offer->updated_by = Auth::id();
            }
        });
    }

    /**
     * Accessor: trimmed price (e.g. 0.03500 -> 0.035)
     */
    public function getPriceTrimmedAttribute(): ?string
    {
        if ($this->price === null) {
            return null;
        }

        $value = rtrim(rtrim(number_format((float) $this->price, 10, '.', ''), '0'), '.');

        if ($value === '-0') {
            $value = '0';
        }

        return $value;
    }

    // Relationships

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
        return $this->belongsTo(NetworkMnc::class, 'network_mnc_id');
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

    public function knownHopsDropdown()
    {
        return $this->belongsTo(DropdownItem::class, 'known_hops_dropdown_item_id');
    }

    public function senderIdSupportedDropdown()
    {
        return $this->belongsTo(DropdownItem::class, 'sender_id_supported_dropdown_item_id');
    }

    public function updatedBy()
    {
        return $this->belongsTo(User::class, 'updated_by');
    }
}
