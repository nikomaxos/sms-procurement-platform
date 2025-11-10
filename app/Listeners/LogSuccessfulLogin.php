<?php
namespace App\Listeners;
use Illuminate\Auth\Events\Login;
use App\Models\AuthLog;
class LogSuccessfulLogin {
    public function handle(Login $event): void {
        AuthLog::create([
            'user_id'    => $event->user->id ?? null,
            'event'      => 'login',
            'ip'         => request()?->ip(),
            'user_agent' => request()?->userAgent(),
        ]);
    }
}
