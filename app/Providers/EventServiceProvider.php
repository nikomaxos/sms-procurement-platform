<?php
namespace App\Providers;
use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\Logout;
use App\Listeners\LogSuccessfulLogin;
use App\Listeners\LogSuccessfulLogout;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;
class EventServiceProvider extends ServiceProvider
{
    protected $listen = [
        Login::class  => [LogSuccessfulLogin::class],
        Logout::class => [LogSuccessfulLogout::class],
    ];
    public function boot(): void { parent::boot(); }
}
