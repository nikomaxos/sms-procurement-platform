<?php

namespace App\Models;

use App\Support\MccMncNormalizer;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMnc extends Model
{
    protected $table = 'network_mncs';

    protected $fillable = [
        'network_id',
        'mcc',
        'mnc',
        'mcc_mnc',
        'marked_for_deletion',
        'created_by_user_id',
        'updated_by_user_id',
        'created_by_source',
        'updated_by_source',
    ];

    protected $casts = [
        'marked_for_deletion' => 'bool',
    ];

    /**
     * Always recompute mcc_mnc on save using MccMncNormalizer.
     * This covers:
     * - Manual add/edit in the Networks UI.
     * - Any import job that persists NetworkMnc rows.
     */
    protected static function booted(): void
    {
        static::saving(function (NetworkMnc $model): void {
            if ($model->mcc === null || $model->mnc === null) {
                return;
            }

            $mcc = str_pad((string) $model->mcc, 3, '0', STR_PAD_LEFT);
            $mnc = str_pad((string) $model->mnc, 3, '0', STR_PAD_LEFT);

            $raw = $mcc . $mnc;

            if (class_exists(MccMncNormalizer::class)) {
                $model->mcc_mnc = MccMncNormalizer::normalize($raw);
            } else {
                $model->mcc_mnc = $raw;
            }
        });
    }

    public function network(): BelongsTo
    {
        return $this->belongsTo(Network::class);
    }

    /**
     * Simple accessor for MCC+MNC as a 6-digit string (for display).
     * Note: This uses the separate mcc/mnc columns, not the normalized mcc_mnc.
     */
    public function getMccMncFormattedAttribute(): string
    {
        $mcc = str_pad((string) $this->mcc, 3, '0', STR_PAD_LEFT);
        $mnc = str_pad((string) $this->mnc, 3, '0', STR_PAD_LEFT);

        return $mcc . $mnc;
    }
}
