#!/usr/bin/env bash
set -Eeuo pipefail

run() { if docker compose ps app >/dev/null 2>&1; then docker compose exec -T app bash -lc "$*"; else bash -lc "$*"; fi; }

[[ -f artisan ]] || { echo "[x] Run from Laravel project root"; exit 1; }

echo "[1/8] Fix User model (fillable/casts)"
mkdir -p app/Models
cat > app/Models/User.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    use HasFactory, Notifiable;

    protected $fillable = ['name','email','password','is_admin'];

    protected $hidden = ['password','remember_token'];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'is_admin' => 'boolean',
    ];
}
PHP

echo "[2/8] Ensure UserObserver (hash password / default)"
mkdir -p app/Observers
cat > app/Observers/UserObserver.php <<'PHP'
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
PHP

echo "[3/8] AppServiceProvider: admin Gate + observe User"
cat > app/Providers/AppServiceProvider.php <<'PHP'
<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\Gate;
use App\Models\User;
use App\Observers\UserObserver;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void {}

    public function boot(): void
    {
        Gate::define('admin', fn($user) => (bool) $user->is_admin);
        User::observe(UserObserver::class);
    }
}
PHP

echo "[4/8] AuthLog model + migration + controller + view"
# Model
cat > app/Models/AuthLog.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;

class AuthLog extends Model
{
    protected $fillable = ['user_id','event','ip','user_agent'];
    public function user(){ return $this->belongsTo(\App\Models\User::class); }
}
PHP

# Migration if absent
if ! ls database/migrations/*_create_auth_logs_table.php >/dev/null 2>&1; then
  ts=$(date +%Y_%m_%d_%H%M%S)
  cat > database/migrations/${ts}_create_auth_logs_table.php <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('auth_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('event', 20); // login|logout
            $table->string('ip', 64)->nullable();
            $table->text('user_agent')->nullable();
            $table->timestamps();
        });
    }
    public function down(): void { Schema::dropIfExists('auth_logs'); }
};
PHP
fi

# Controller
mkdir -p app/Http/Controllers/Settings
cat > app/Http/Controllers/Settings/AuthLogController.php <<'PHP'
<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\AuthLog;

class AuthLogController extends Controller
{
    public function index()
    {
        $logs = AuthLog::with('user')->latest()->paginate(50);
        return view('settings.logs.index', compact('logs'));
    }
}
PHP

# View
mkdir -p resources/views/settings/logs
cat > resources/views/settings/logs/index.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="section-title">{{ __('Authentication Logs') }}</h2>
        <p class="section-subtitle">{{ __('Recent sign-ins and sign-outs') }}</p>
    </x-slot>

    <div class="card overflow-x-auto">
        <table class="min-w-full text-sm">
            <thead class="text-left text-gray-600">
                <tr>
                    <th class="py-2 pe-4">{{ __('When') }}</th>
                    <th class="py-2 pe-4">{{ __('User') }}</th>
                    <th class="py-2 pe-4">{{ __('Event') }}</th>
                    <th class="py-2 pe-4">{{ __('IP') }}</th>
                    <th class="py-2 pe-4">{{ __('User-Agent') }}</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
                @foreach($logs as $log)
                <tr>
                    <td class="py-2 pe-4 text-gray-800">{{ $log->created_at->format('Y-m-d H:i:s') }}</td>
                    <td class="py-2 pe-4">
                        @if($log->user)
                            <span class="font-medium text-gray-900">{{ $log->user->name }}</span>
                            <span class="text-gray-500">({{ $log->user->email }})</span>
                        @else
                            <span class="text-gray-500">—</span>
                        @endif
                    </td>
                    <td class="py-2 pe-4">
                        <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold
                            {{ $log->event === 'login' ? 'bg-green-100 text-green-800' : 'bg-amber-100 text-amber-800' }}">
                            {{ ucfirst($log->event) }}
                        </span>
                    </td>
                    <td class="py-2 pe-4 text-gray-700">{{ $log->ip ?? '—' }}</td>
                    <td class="py-2 pe-4 text-gray-500 max-w-[32rem] truncate" title="{{ $log->user_agent }}">{{ $log->user_agent }}</td>
                </tr>
                @endforeach
            </tbody>
        </table>

        <div class="mt-4">{{ $logs->links() }}</div>
    </div>
</x-app-layout>
BLADE

echo "[5/8] Record login/logout into auth_logs"
cat > app/Providers/EventServiceProvider.php <<'PHP'
<?php

namespace App\Providers;

use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\Logout;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\Event;
use App\Models\AuthLog;

class EventServiceProvider extends ServiceProvider
{
    protected $listen = [
        // You can also register listeners here if you prefer classes.
    ];

    public function boot(): void
    {
        Event::listen(Login::class, function ($event) {
            AuthLog::create([
                'user_id' => $event->user->id ?? null,
                'event' => 'login',
                'ip' => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);
        });

        Event::listen(Logout::class, function ($event) {
            AuthLog::create([
                'user_id' => $event->user->id ?? null,
                'event' => 'logout',
                'ip' => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);
        });
    }
}
PHP

echo "[6/8] UI polish (colors/spacing/cards/category look)"
css="resources/css/app.css"
mkdir -p "$(dirname "$css")"
if ! grep -q "UI polish (readability, spacing)" "$css" 2>/dev/null; then
cat >> "$css" <<'CSS'

/* === UI polish (readability, spacing) === */
@layer base {
  body { @apply bg-gray-50 text-gray-900; }
  a { @apply text-blue-700 hover:text-blue-900; }
}

@layer components {
  .card { @apply bg-white border border-gray-200 rounded-2xl shadow-sm p-6; }
  .section-title { @apply text-xl font-semibold text-gray-900; }
  .section-subtitle { @apply text-sm text-gray-500; }
  .category { @apply card mb-6; }
  .category h3 { @apply text-lg font-semibold text-gray-800 mb-1; }
  .category p { @apply text-sm text-gray-500 mb-4; }
  .table { @apply min-w-full text-sm; }
  .btn { @apply inline-flex items-center px-3 py-2 rounded-md font-medium border border-gray-300 bg-white text-gray-700 hover:bg-gray-50; }
  .btn-primary { @apply inline-flex items-center px-3 py-2 rounded-md font-semibold bg-blue-600 text-white hover:bg-blue-700; }
  .input { @apply rounded-md border-gray-300 focus:border-blue-500 focus:ring-blue-500; }
}
CSS
fi

echo "[7/8] Migrate & build assets"
run "php artisan migrate --force"
if docker compose ps node >/dev/null 2>&1; then docker compose run --rm node 'npm ci && npm run build'; else npm ci && npm run build; fi

echo "[8/8] Clear caches & restart"
run "php artisan view:clear && php artisan route:clear && php artisan config:clear"
docker compose restart app web >/dev/null || true

echo "[✓] Repair complete. Visit /settings/users, /settings/dropdowns, /settings/logs"
