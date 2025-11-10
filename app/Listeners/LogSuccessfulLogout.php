<?php
namespace App\Listeners;
use Illuminate\Auth\Events\Logout;
use App\Models\AuthLog;
class LogSuccessfulLogout {
    public function handle(Logout $event): void {
        AuthLog::create([
            'user_id'    => $event->user->id ?? null,
            'event'      => 'logout',
            'ip'         => request()?->ip(),
            'user_agent' => request()?->userAgent(),
        ]);
    }
}
