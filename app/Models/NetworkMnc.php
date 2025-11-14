<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMnc extends Model {
    protected $fillable = ['network_id','mcc','mnc','mcc_mnc','created_by_user_id','updated_by_user_id'];
    public function network(): BelongsTo { return $this->belongsTo(Network::class); }
    protected static function booted() {
        static::saving(function($m){
            $m->mcc = (string)($m->mcc ?? '');
            $m->mnc = (string)($m->mnc ?? '');
            $m->mcc_mnc = ($m->mcc ?? '').($m->mnc ?? '');
        });
    }
}
