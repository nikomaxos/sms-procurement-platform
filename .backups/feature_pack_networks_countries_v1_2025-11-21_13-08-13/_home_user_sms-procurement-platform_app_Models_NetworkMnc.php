<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMnc extends Model
{
    protected $table = 'network_mncs';

    protected $fillable = [
        'network_id','mcc','mnc','mcc_mnc',
        'marked_for_deletion',
        'created_by_user_id','updated_by_user_id',
        'created_by_source','updated_by_source',
    ];

    protected $casts = [
        'marked_for_deletion' => 'bool',
    ];

    public function network(): BelongsTo
    {
        return $this->belongsTo(Network::class);
    }

    public function getMccMncFormattedAttribute(): string
    {
        $mcc = str_pad((string)$this->mcc, 3, '0', STR_PAD_LEFT);
        $mnc = str_pad((string)$this->mnc, 3, '0', STR_PAD_LEFT);
        return $mcc.$mnc;
    }
}
