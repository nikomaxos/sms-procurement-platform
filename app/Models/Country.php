<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Country extends Model {
  protected $fillable = ['name','iso2'];
  public function mccs(){ return $this->hasMany(CountryMcc::class); }
  public function networks(){ return $this->hasMany(Network::class); }
}
