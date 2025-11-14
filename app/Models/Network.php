<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Network extends Model {
    protected $fillable = [
        'name','country_id','marked_for_deletion',
        'created_by_user_id','updated_by_user_id','created_by_source','updated_by_source'
    ];
    protected $casts = ['marked_for_deletion'=>'bool'];

    public function country(): BelongsTo { return $this->belongsTo(Country::class); }
    public function mncs(): HasMany { return $this->hasMany(NetworkMnc::class)->orderBy('mnc'); }

    # Helpers for list view
    public function getMccListAttribute() {
        return $this->mncs->pluck('mcc')->filter()->unique()->values();
    }
    public function getMncListAttribute() {
        return $this->mncs->pluck('mnc')->filter()->values();
    }
    public function getAnyMccMncAttribute() {
        $m=$this->mncs->first(); return $m ? $m->mcc.$m->mnc : null;
    }
}
