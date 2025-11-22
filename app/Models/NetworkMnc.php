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
     * Always recompute mcc, mnc, and mcc_mnc on save using MccMncNormalizer.
     *
     * This covers:
     * - Manual add/edit in the Networks UI.
     * - Any import job that persists NetworkMnc rows through Eloquent.
     *
     * Rule:
     *  - Build a 6-digit raw MCCMNC from MCC(3) + MNC(3) (padded).
     *  - Normalize via MccMncNormalizer (which trims the 4th digit 0 => 5-digit code).
     *  - Re-split normalized value into MCC (first 3) and MNC (last 2 or 3).
     *  - Persist all three: mcc, mnc, mcc_mnc.
     *
     * NOTE: There is also a DB trigger (normalize_network_mncs) on the network_mncs table
     * that enforces the same rule at the database level for raw inserts.
     */
    protected static function booted(): void
    {
        static::saving(function (NetworkMnc $model): void {
            if ($model->mcc === null || $model->mnc === null) {
                return;
            }

            // Sanitise into digits
            $mccDigits = preg_replace('/\D/', '', (string) $model->mcc);
            $mncDigits = preg_replace('/\D/', '', (string) $model->mnc);

            if ($mccDigits === '' || $mncDigits === '') {
                return;
            }

            // Build raw 6-digit MCCMNC from padded parts (3+3)
            $raw = str_pad($mccDigits, 3, '0', STR_PAD_LEFT)
                 . str_pad($mncDigits, 3, '0', STR_PAD_LEFT);

            $normalized = $raw;

            if (class_exists(MccMncNormalizer::class)) {
                $normalized = MccMncNormalizer::normalize($raw);
            } else {
                $normalized = preg_replace('/\D/', '', $raw);
            }

            $normalized = (string) $normalized;
            $len = strlen($normalized);

            if ($len < 5) {
                // Fallback: keep original ints, but at least store something in mcc_mnc
                $model->mcc_mnc = $normalized !== '' ? $normalized : $raw;
                return;
            }

            // MCC is always the first 3 digits
            $mccNorm = substr($normalized, 0, 3);

            // For 5-digit: MCC(3) + MNC(2)
            // For 6-digit: MCC(3) + MNC(3)
            if ($len === 5) {
                $mncNorm = substr($normalized, 3, 2);
            } else {
                $mncNorm = substr($normalized, 3);
            }

            $model->mcc = (int) $mccNorm;
            $model->mnc = (int) $mncNorm;
            $model->mcc_mnc = $normalized;
        });
    }

    public function network(): BelongsTo
    {
        return $this->belongsTo(Network::class);
    }

    /**
     * Accessor for formatted MCCMNC.
     *
     * Prefer the normalized mcc_mnc column if present; otherwise rebuild from mcc/mnc.
     */
    public function getMccMncFormattedAttribute(): string
    {
        if (!empty($this->mcc_mnc)) {
            return (string) $this->mcc_mnc;
        }

        $mcc = str_pad((string) $this->mcc, 3, '0', STR_PAD_LEFT);

        $mncStr = (string) $this->mnc;
        if ($mncStr === '') {
            return $mcc;
        }

        // If 1–2 digits, show as 2-digit; if 3+, show as-is
        $len = strlen($mncStr);
        if ($len <= 2) {
            $mnc = str_pad($mncStr, 2, '0', STR_PAD_LEFT);
        } else {
            $mnc = $mncStr;
        }

        return $mcc . $mnc;
    }
}
