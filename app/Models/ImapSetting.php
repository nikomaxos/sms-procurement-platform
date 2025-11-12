<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ImapSetting extends Model {
    protected $table = 'imap_settings';
    protected $guarded = [];
    protected $casts = [
        'enabled'            => 'bool',
        'selected_folders'   => 'array',
        'last_folders_cache' => 'array',
        'last_run_at'        => 'datetime',
    ];
    public static function singleton(): self {
        $m = static::find(1);
        if (!$m) { $m = new static(); $m->id = 1; $m->poll_minutes = 5; $m->save(); }
        return $m;
    }
}
