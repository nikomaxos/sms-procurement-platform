<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

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
    ];

    protected $casts = [
        'is_exclusive'   => 'boolean',
        'effective_date' => 'date',
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

    public function getProductTypeLabelAttribute()
    {
        if ($this->productTypeDropdown) {
            return $this->productTypeDropdown->label;
        }

        return $this->product_type;
    }

    public function getKnownHopsLabelAttribute()
    {
        return optional($this->knownHopsDropdown)->label;
    }

    public function getSenderIdSupportedLabelAttribute()
    {
        return optional($this->senderIdSupportedDropdown)->label;
    }

    /**
     * Price χωρίς περιττά trailing zeros (0.03500 -> 0.035)
     */
    public function getPriceTrimmedAttribute()
    {
        if ($this->price === null) {
            return null;
        }

        $value = (string) $this->price;
        $value = rtrim(rtrim($value, '0'), '.');

        if ($value === '' || $value === '-0') {
            return '0';
        }

        return $value;
    }

    /**
     * Charge type human readable (per_submit -> Per Submit)
     */
    public function getChargeTypeLabelAttribute()
    {
        if ($this->charge_type === null || $this->charge_type === '') {
            return null;
        }

        $label = str_replace('_', ' ', $this->charge_type);

        if (function_exists('mb_convert_case')) {
            return mb_convert_case($label, MB_CASE_TITLE, 'UTF-8');
        }

        return ucwords($label);
    }
}
