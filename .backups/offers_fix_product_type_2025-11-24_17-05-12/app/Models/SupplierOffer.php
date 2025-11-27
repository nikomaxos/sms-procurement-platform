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
    // === Offers listview helper block (auto-added) ===

    // Accessor: return price without trailing zeros (e.g. 0.030500 -> 0.0305)
    public function getPriceAttribute($value)
    {
        if ($value === null) {
            return null;
        }
        $str = (string) $value;
        if (strpos($str, '.') !== false) {
            $str = rtrim(rtrim($str, '0'), '.');
        }
        return $str;
    }

    // Mutator: normalize price before saving (strip extra zeros and non-numeric chars)
    public function setPriceAttribute($value)
    {
        if ($value === null || $value === '') {
            $this->attributes["price"] = null;
            return;
        }
        $str = preg_replace("/[^0-9.]/", "", (string) $value);
        if ($str == '' or $str == '.') {
            $this->attributes["price"] = null;
            return;
        }
        if (strpos($str, '.') !== false) {
            $str = rtrim(rtrim($str, '0'), '.');
        }
        $this->attributes["price"] = $str;
    }

    // UI accessor for product_type (offer column, dropdown id, or connection fallback)
    public function getProductTypeAttribute()
    {
        if (array_key_exists("product_type", $this->attributes ?? []) && $this->attributes["product_type"] !== null && $this->attributes["product_type"] !== "") {
            return $this->attributes["product_type"];
        }

        if (array_key_exists("product_type_dropdown_item_id", $this->attributes ?? [])) {
            $id = (int) $this->attributes["product_type_dropdown_item_id"];
            if ($id > 0 && class_exists("\App\Models\DropdownItem")) {
                $item = \App\Models\DropdownItem::find($id);
                if ($item) {
                    return $item->label;
                }
            }
        }

        try {
            if (method_exists($this, "connection")) {
                $conn = $this->connection;
                if ($conn && !empty($conn->product_type)) {
                    return $conn->product_type;
                }
            }
        } catch (\Throwable $e) {
            // ignore
        }

        return null;
    }

    // UI accessor for known_hops
    public function getKnownHopsAttribute()
    {
        if (array_key_exists("known_hops", $this->attributes ?? []) && $this->attributes["known_hops"] !== null && $this->attributes["known_hops"] !== "") {
            return $this->attributes["known_hops"];
        }

        if (array_key_exists("known_hops_dropdown_item_id", $this->attributes ?? [])) {
            $id = (int) $this->attributes["known_hops_dropdown_item_id"];
            if ($id > 0 && class_exists("\App\Models\DropdownItem")) {
                $item = \App\Models\DropdownItem::find($id);
                if ($item) {
                    return $item->label;
                }
            }
        }

        try {
            if (method_exists($this, "connection")) {
                $conn = $this->connection;
                if ($conn && !empty($conn->known_hops)) {
                    return $conn->known_hops;
                }
            }
        } catch (\Throwable $e) {
            // ignore
        }

        return null;
    }

    // UI accessor for sender_id_supported
    public function getSenderIdSupportedAttribute()
    {
        if (array_key_exists("sender_id_supported", $this->attributes ?? []) and $this->attributes["sender_id_supported"] !== null and $this->attributes["sender_id_supported"] != "") {
            return $this->attributes["sender_id_supported"];
        }

        if (array_key_exists("sender_id_supported_dropdown_item_id", $this->attributes ?? [])) {
            $id = (int) $this->attributes["sender_id_supported_dropdown_item_id"];
            if ($id > 0 and class_exists("\App\Models\DropdownItem")) {
                $item = \App\Models\DropdownItem::find($id);
                if ($item) {
                    return $item->label;
                }
            }
        }

        try {
            if (method_exists($this, "connection")) {
                $conn = $this->connection;
                if ($conn) {
                    if (!empty($conn->sender_id_supported)) {
                        return $conn->sender_id_supported;
                    }
                    if (!empty($conn->senderid_supported)) {
                        return $conn->senderid_supported;
                    }
                    if (!empty($conn->sender_id_support)) {
                        return $conn->sender_id_support;
                    }
                }
            }
        } catch (\Throwable $e) {
            // ignore
        }

        return null;
    }


}
