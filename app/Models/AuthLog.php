<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;

class AuthLog extends Model
{
    protected $fillable = ['user_id','event','ip','user_agent'];
    public function user(){ return $this->belongsTo(\App\Models\User::class); }
}
