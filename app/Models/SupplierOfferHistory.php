<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SupplierOfferHistory extends Model
{
    use HasFactory;

    protected $guarded = [];

    public function offer()
    {
        return $this->belongsTo(SupplierOffer::class, 'supplier_offer_id');
    }

    public function connection()
    {
        return $this->belongsTo(SupplierConnection::class, 'supplier_connection_id');
    }
}
