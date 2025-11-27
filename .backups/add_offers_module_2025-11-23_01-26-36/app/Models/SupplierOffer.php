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
