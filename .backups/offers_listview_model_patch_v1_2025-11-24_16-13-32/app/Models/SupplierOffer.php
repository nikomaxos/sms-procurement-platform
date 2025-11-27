<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SupplierOffer extends Model
{
    use HasFactory;

    // Allow mass-assignment via validated input
    protected $guarded = [];

    protected $casts = [
        'price'          => 'decimal:6',
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
        return $this->belongsTo(NetworkMnc::class);
    }

    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }

    /**
     * Main relation to the supplier connection (FK: supplier_connection_id)
     */
    public function supplierConnection()
    {
        return $this->belongsTo(SupplierConnection::class, 'supplier_connection_id');
    }

    /**
     * Alias used as $offer->connection so ->with('connection') works.
     */
    public function connection()
    {
        return $this->belongsTo(SupplierConnection::class, 'supplier_connection_id');
    }

    /**
     * Dropdown item for Product Type (e.g. Direct / Reseller / Aggregator)
     */
    public function productType()
    {
        return $this->belongsTo(DropdownItem::class, 'product_type_dropdown_item_id');
    }

    /**
     * Dropdown item for Known Hops.
     */
    public function knownHopsItem()
    {
        return $this->belongsTo(DropdownItem::class, 'known_hops_dropdown_item_id');
    }

    /**
     * Dropdown item for Sender ID Supported.
     */
    public function senderIdSupportedItem()
    {
        return $this->belongsTo(DropdownItem::class, 'sender_id_supported_dropdown_item_id');
    }
}
