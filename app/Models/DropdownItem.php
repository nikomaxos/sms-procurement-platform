<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DropdownItem extends Model
{
    protected $fillable = ['label', 'dropdown_menu_id'];

    public function menu(): BelongsTo {
        return $this->belongsTo(DropdownMenu::class, 'dropdown_menu_id');
    }
}
