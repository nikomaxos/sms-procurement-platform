<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class CountryMcc extends Model {
  protected $fillable = ['country_id','mcc'];
  public function country(){ return $this->belongsTo(Country::class); }
}
