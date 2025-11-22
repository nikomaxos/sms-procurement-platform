<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Supplier extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'email',
        'notes',
    ];
    public function connections()
    {
        return ->hasMany(\App\Models\SupplierConnection::class);
    }
}
