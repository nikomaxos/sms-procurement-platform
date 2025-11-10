<?php
namespace App\Observers;

use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class UserObserver
{
    public function creating(User $user): void
    {
        if (empty($user->password)) {
            $user->password = Hash::make(Str::random(16));
        } elseif (!Str::startsWith($user->password, '$2y$')) {
            $user->password = Hash::make($user->password);
        }
    }

    public function updating(User $user): void
    {
        if ($user->isDirty('password') && !empty($user->password) && !\Illuminate\Support\Str::startsWith($user->password, '$2y$')) {
            $user->password = Hash::make($user->password);
        }
    }
}
