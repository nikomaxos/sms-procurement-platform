<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMeta extends Model
{
    protected $table = 'network_meta';

    protected $fillable = [
        'network_id',
        'non_operational',
        'notes',
    ];

    protected $casts = [
        'non_operational' => 'bool',
    ];

    public function network(): BelongsTo
    {
        return $this->belongsTo(Network::class);
    }
}
