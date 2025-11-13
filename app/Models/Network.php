<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Network extends Model {
  protected $fillable=['name','mcc','mnc','mcc_mnc','country_id'];
  public function country(){ return $this->belongsTo(Country::class); }
}
