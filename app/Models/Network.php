<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Str;

class Network extends Model
{
    protected $fillable = [
        'name',
        'country_id',
    ];

    public $timestamps = true;

    protected static function booted(): void
    {
        static::saving(function (self $model): void {
            $model->lower_name = Str::lower((string) $model->name);
        });
    }

    public function country(): BelongsTo
    {
        return $this->belongsTo(\App\Models\Country::class);
    }

    public function mncs(): HasMany
    {
        return $this->hasMany(\App\Models\NetworkMnc::class);
    }

    public function meta(): HasOne
    {
        return $this->hasOne(\App\Models\NetworkMeta::class);
    }

    /**
     * Simple filters for index page.
     */
    public function scopeFilter($query, array $filters)
    {
        if (!empty($filters['q'])) {
            $search = mb_strtolower(trim((string) $filters['q']));
            $query->whereRaw('lower(name) like ?', ['%' . $search . '%']);
        }

        if (!empty($filters['country_id']) && ctype_digit((string) $filters['country_id'])) {
            $query->where('country_id', (int) $filters['country_id']);
        }

        if (!empty($filters['mcc'])) {
            $mcc = preg_replace('/\D/', '', (string) $filters['mcc']);
            if ($mcc !== '') {
                $query->whereHas('mncs', function ($q) use ($mcc) {
                    $q->where('mcc', $mcc);
                });
            }
        }

        if (!empty($filters['mnc'])) {
            $mnc = preg_replace('/\D/', '', (string) $filters['mnc']);
            if ($mnc !== '') {
                $query->whereHas('mncs', function ($q) use ($mnc) {
                    $q->where('mnc', $mnc);
                });
            }
        }

        return $query;
    }
}
