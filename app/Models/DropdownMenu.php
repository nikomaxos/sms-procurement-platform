<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DropdownMenu extends Model
{
    protected $fillable = ['title', 'module'];

    public function items(): HasMany
    {
        return $this->hasMany(DropdownItem::class);
    }
}
