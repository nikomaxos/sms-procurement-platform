<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SupplierConnection extends Model
{
    use HasFactory;

    public const CHARGE_TYPE_PER_SUBMIT    = 'per_submit';
    public const CHARGE_TYPE_PER_DELIVERED = 'per_delivered';

    public static function chargeTypeOptions(): array
    {
        return [
            self::CHARGE_TYPE_PER_SUBMIT    => 'Per Submit',
            self::CHARGE_TYPE_PER_DELIVERED => 'Per Delivered',
        ];
    }

    protected $fillable = [
        'supplier_id',
        'name',
        'username',
        'charge_type',
        'product_type',
        'notes',
    ];

    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }

    public function getChargeTypeLabelAttribute(): string
    {
        return static::chargeTypeOptions()[$this->charge_type] ?? (string) $this->charge_type;
    }
}
