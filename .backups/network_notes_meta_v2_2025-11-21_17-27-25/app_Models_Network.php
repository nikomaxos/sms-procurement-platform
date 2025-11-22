<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Network extends Model
{
    protected $fillable = ['name','country_id'];
    public $timestamps = true;

    protected static function booted(): void
    {
        static::saving(function (self $model) {
            $model->lower_name = Str::lower((string)$model->name);
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

    /** Simple filters for index page */
    public function scopeFilter($q, array $f)
    {
        if (!empty($f['q'])) {
            $s = mb_strtolower(trim((string)$f['q']));
            $q->whereRaw('lower(name) like ?', ['%'.$s.'%']);
        }
        if (!empty($f['country_id']) && ctype_digit((string)$f['country_id'])) {
            $q->where('country_id', (int)$f['country_id']);
        }
        if (!empty($f['mcc'])) {
            $mcc = preg_replace('/\D/','',(string)$f['mcc']);
            if ($mcc !== '') {
                $q->whereHas('mncs', fn($qq)=>$qq->where('mcc',$mcc));
            }
        }
        if (!empty($f['mnc'])) {
            $mnc = preg_replace('/\D/','',(string)$f['mnc']);
            if ($mnc !== '') {
                $q->whereHas('mncs', fn($qq)=>$qq->where('mnc',$mnc));
            }
        }
        return $q;
    }


    public function meta()
    {
        return $this->hasOne(\App\Models\NetworkMeta::class);
    }

}
