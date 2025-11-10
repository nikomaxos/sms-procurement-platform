#!/usr/bin/env bash
set -Eeuo pipefail

run() {
  if docker compose ps app >/dev/null 2>&1; then docker compose exec -T app bash -lc "$*"; else bash -lc "$*"; fi
}

[[ -f artisan ]] || { echo "[x] Run from Laravel project root"; exit 1; }

echo "[*] 1) Ensure AuthLog model, migration, controller & view"
# Model
mkdir -p app/Models
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

# Migration (only if absent)
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

echo "[*] 2) Make User creation reliable (observer + fillable/casts)"
# Observer hashes passwords and sets default if missing
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
        if ($user->isDirty('password') && !empty($user->password)) {
            if (!\Illuminate\Support\Str::startsWith($user->password, '$2y$')) {
                $user->password = Hash::make($user->password);
            }
        }
    }
}
PHP

# Ensure AppServiceProvider registers the observer and admin Gate
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

# Ensure User is mass-assignable + proper casts
php -r '
$f="app/Models/User.php";
if(!file_exists($f)) exit(0);
$s=file_get_contents($f);
if(strpos($s,"is_admin")===false){
  $s=preg_replace("/protected \\$fillable = \\[[^\\]]*\\];/s",
    "protected \$fillable = [\"name\",\"email\",\"password\",\"is_admin\"];",
    $s,1);
  if(strpos($s,"protected \$casts")===false){
    $s=preg_replace("/class User extends Authenticatable\\R\\{/",
      "class User extends Authenticatable\n{\n    protected \$casts = [\n        'email_verified_at' => 'datetime',\n        'is_admin' => 'boolean',\n    ];\n",
      $s,1);
  } else {
    $s=preg_replace("/protected \\$casts = \\[[^\\]]*\\];/s",
      "protected \$casts = [\n        'email_verified_at' => 'datetime',\n        'is_admin' => 'boolean',\n    ];",
      $s,1);
  }
  file_put_contents($f,$s);
}
'

echo "[*] 3) Improve readability: colors, spacing, cards, category layout"
# Tailwind app.css enhancements
css="resources/css/app.css"
if ! grep -q "@layer base" "$css"; then
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

# Drop-downs page with category layout (replace/ensure clean)
mkdir -p resources/views/settings/dropdowns
cat > resources/views/settings/dropdowns/index.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="section-title">{{ __('Drop-down menus') }}</h2>
        <p class="section-subtitle">{{ __('Manage lists used by supplier offers') }}</p>
    </x-slot>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {{-- Route Types --}}
        <div class="category">
            <h3>{{ __('Route Type') }}</h3>
            <p>{{ __('Direct, HQ, SS7, SIM, Local Bypass') }}</p>

            <form method="POST" action="{{ route('settings.route-types.store') }}" class="mb-4">
                @csrf
                <div class="flex gap-2">
                    <input name="name" type="text" class="input w-full" placeholder="{{ __('Add new type…') }}">
                    <button class="btn-primary">{{ __('Add') }}</button>
                </div>
            </form>

            <div class="overflow-x-auto">
                <table class="table">
                    <tbody class="divide-y divide-gray-200">
                        @foreach($routeTypes as $item)
                        <tr>
                            <td class="py-2 pe-2 w-full">{{ $item->name }}</td>
                            <td class="py-2 pe-2">
                                <form method="POST" action="{{ route('settings.route-types.update', $item) }}" class="flex gap-2">
                                    @csrf @method('PUT')
                                    <input name="name" value="{{ $item->name }}" class="input" />
                                    <button class="btn-primary">{{ __('Save') }}</button>
                                </form>
                            </td>
                            <td class="py-2">
                                <form method="POST" action="{{ route('settings.route-types.destroy', $item) }}" onsubmit="return confirm('Delete?')">
                                    @csrf @method('DELETE')
                                    <button class="btn">{{ __('Delete') }}</button>
                                </form>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>

        {{-- Known Hops --}}
        <div class="category">
            <h3>{{ __('Known Hops') }}</h3>
            <p>{{ __('0-Hop, 1-Hop, 2-Hops, N-Hops') }}</p>

            <form method="POST" action="{{ route('settings.known-hops.store') }}" class="mb-4">
                @csrf
                <div class="flex gap-2">
                    <input name="name" type="text" class="input w-full" placeholder="{{ __('Add new hop…') }}">
                    <button class="btn-primary">{{ __('Add') }}</button>
                </div>
            </form>

            <div class="overflow-x-auto">
                <table class="table">
                    <tbody class="divide-y divide-gray-200">
                        @foreach($knownHops as $item)
                        <tr>
                            <td class="py-2 pe-2 w-full">{{ $item->name }}</td>
                            <td class="py-2 pe-2">
                                <form method="POST" action="{{ route('settings.known-hops.update', $item) }}" class="flex gap-2">
                                    @csrf @method('PUT')
                                    <input name="name" value="{{ $item->name }}" class="input" />
                                    <button class="btn-primary">{{ __('Save') }}</button>
                                </form>
                            </td>
                            <td class="py-2">
                                <form method="POST" action="{{ route('settings.known-hops.destroy', $item) }}" onsubmit="return confirm('Delete?')">
                                    @csrf @method('DELETE')
                                    <button class="btn">{{ __('Delete') }}</button>
                                </form>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>

        {{-- Charge Models --}}
        <div class="category">
            <h3>{{ __('Charge Model') }}</h3>
            <p>{{ __('Per Submit, Per Delivered') }}</p>

            <form method="POST" action="{{ route('settings.charge-models.store') }}" class="mb-4">
                @csrf
                <div class="flex gap-2">
                    <input name="name" type="text" class="input w-full" placeholder="{{ __('Add new model…') }}">
                    <button class="btn-primary">{{ __('Add') }}</button>
                </div>
            </form>

            <div class="overflow-x-auto">
                <table class="table">
                    <tbody class="divide-y divide-gray-200">
                        @foreach($chargeModels as $item)
                        <tr>
                            <td class="py-2 pe-2 w-full">{{ $item->name }}</td>
                            <td class="py-2 pe-2">
                                <form method="POST" action="{{ route('settings.charge-models.update', $item) }}" class="flex gap-2">
                                    @csrf @method('PUT')
                                    <input name="name" value="{{ $item->name }}" class="input" />
                                    <button class="btn-primary">{{ __('Save') }}</button>
                                </form>
                            </td>
                            <td class="py-2">
                                <form method="POST" action="{{ route('settings.charge-models.destroy', $item) }}" onsubmit="return confirm('Delete?')">
                                    @csrf @method('DELETE')
                                    <button class="btn">{{ __('Delete') }}</button>
                                </form>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</x-app-layout>
BLADE

echo "[*] 4) Migrate DB and rebuild assets"
run "php artisan migrate --force"
if docker compose ps node >/dev/null 2>&1; then
  docker compose run --rm node 'npm ci && npm run build'
else
  npm ci && npm run build
fi

echo "[*] 5) Clear caches and restart"
run "php artisan config:clear"
run "php artisan view:clear"
run "php artisan route:clear"
docker compose restart app web >/dev/null || true

echo "[+] Done. Open /settings/dropdowns and /settings/logs"
