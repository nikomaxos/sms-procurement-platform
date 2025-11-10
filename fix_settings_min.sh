#!/usr/bin/env bash
set -Eeuo pipefail

# Run inside Docker if available
run() {
  if docker compose ps app >/dev/null 2>&1; then
    docker compose exec -T app bash -lc "$*"
  else
    bash -lc "$*"
  fi
}

[[ -f artisan ]] || { echo "[x] Run from Laravel project root."; exit 1; }

echo "[*] Backups"
cp -n routes/web.php routes/web.php.bak.$(date +%F_%H%M%S) 2>/dev/null || true
cp -n app/Providers/EventServiceProvider.php app/Providers/EventServiceProvider.php.bak.$(date +%F_%H%M%S) 2>/dev/null || true

echo "[*] Restore clean EventServiceProvider"
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
        // Using closures in boot
    ];

    public function boot(): void
    {
        Event::listen(Login::class, function ($event) {
            AuthLog::create([
                'user_id'    => optional($event->user)->id,
                'event'      => 'login',
                'ip'         => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);
        });

        Event::listen(Logout::class, function ($event) {
            AuthLog::create([
                'user_id'    => optional($event->user)->id,
                'event'      => 'logout',
                'ip'         => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);
        });
    }
}
PHP

echo "[*] Controllers (dropdowns) with correct unique() validation"
mkdir -p app/Http/Controllers/Settings

# RouteTypeController
cat > app/Http/Controllers/Settings/RouteTypeController.php <<'PHP'
<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\RouteType;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class RouteTypeController extends Controller
{
    public function index() {
        return view('settings.dropdowns.index', [
            'routeTypes'   => \App\Models\RouteType::orderBy('name')->get(),
            'knownHops'    => \App\Models\KnownHop::orderBy('name')->get(),
            'chargeModels' => \App\Models\ChargeModel::orderBy('name')->get(),
        ]);
    }
    public function store(Request $request) {
        $data = $request->validate(['name'=>['required','string','max:100','unique:route_types,name']]);
        RouteType::create($data);
        return back()->with('status','Saved.');
    }
    public function update(Request $request, RouteType $item) {
        $data = $request->validate(['name'=>['required','string','max:100', Rule::unique('route_types','name')->ignore($item->id)]]);
        $item->update($data);
        return back()->with('status','Updated.');
    }
    public function destroy(RouteType $item) {
        $item->delete();
        return back()->with('status','Deleted.');
    }
}
PHP

# KnownHopController
cat > app/Http/Controllers/Settings/KnownHopController.php <<'PHP'
<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\KnownHop;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class KnownHopController extends Controller
{
    public function index() {
        return view('settings.dropdowns.index', [
            'routeTypes'   => \App\Models\RouteType::orderBy('name')->get(),
            'knownHops'    => \App\Models\KnownHop::orderBy('name')->get(),
            'chargeModels' => \App\Models\ChargeModel::orderBy('name')->get(),
        ]);
    }
    public function store(Request $request) {
        $data = $request->validate(['name'=>['required','string','max:100','unique:known_hops,name']]);
        KnownHop::create($data);
        return back()->with('status','Saved.');
    }
    public function update(Request $request, KnownHop $item) {
        $data = $request->validate(['name'=>['required','string','max:100', Rule::unique('known_hops','name')->ignore($item->id)]]);
        $item->update($data);
        return back()->with('status','Updated.');
    }
    public function destroy(KnownHop $item) {
        $item->delete();
        return back()->with('status','Deleted.');
    }
}
PHP

# ChargeModelController
cat > app/Http/Controllers/Settings/ChargeModelController.php <<'PHP'
<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\ChargeModel;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ChargeModelController extends Controller
{
    public function index() {
        return view('settings.dropdowns.index', [
            'routeTypes'   => \App\Models\RouteType::orderBy('name')->get(),
            'knownHops'    => \App\Models\KnownHop::orderBy('name')->get(),
            'chargeModels' => \App\Models\ChargeModel::orderBy('name')->get(),
        ]);
    }
    public function store(Request $request) {
        $data = $request->validate(['name'=>['required','string','max:100','unique:charge_models,name']]);
        ChargeModel::create($data);
        return back()->with('status','Saved.');
    }
    public function update(Request $request, ChargeModel $item) {
        $data = $request->validate(['name'=>['required','string','max:100', Rule::unique('charge_models','name')->ignore($item->id)]]);
        $item->update($data);
        return back()->with('status','Updated.');
    }
    public function destroy(ChargeModel $item) {
        $item->delete();
        return back()->with('status','Deleted.');
    }
}
PHP

echo "[*] Clean up duplicate imports and rewrite Settings routes block"
# Remove any duplicate 'use App\Http\Controllers\Settings\...' imports
sed -i '/^use App\\Http\\Controllers\\Settings\\/d' routes/web.php

# Remove previous managed block if present
sed -i '/BEGIN SETTINGS ROUTES/,/END SETTINGS ROUTES/d' routes/web.php

# Append FQCN routes block (no imports)
cat >> routes/web.php <<'PHP'

// ===== BEGIN SETTINGS ROUTES (managed) =====
Route::middleware(['auth', 'verified'])->group(function () {
    Route::middleware('can:admin')->prefix('settings')->name('settings.')->group(function () {
        Route::get('/', [\App\Http\Controllers\Settings\SettingsController::class, 'index'])->name('index');

        Route::resource('users', \App\Http\Controllers\Settings\UserController::class)->except(['show']);

        Route::get('dropdowns', [\App\Http\Controllers\Settings\RouteTypeController::class, 'index'])->name('dropdowns.index');
        Route::resource('route-types', \App\Http\Controllers\Settings\RouteTypeController::class)->only(['store','update','destroy']);
        Route::resource('known-hops', \App\Http\Controllers\Settings\KnownHopController::class)->only(['store','update','destroy']);
        Route::resource('charge-models', \App\Http\Controllers\Settings\ChargeModelController::class)->only(['store','update','destroy']);

        Route::get('logs', [\App\Http\Controllers\Settings\AuthLogController::class, 'index'])->name('logs.index');
    });
});
// ===== END SETTINGS ROUTES (managed) =====
PHP

echo "[*] Lint modified PHP"
for f in \
  app/Providers/EventServiceProvider.php \
  app/Http/Controllers/Settings/RouteTypeController.php \
  app/Http/Controllers/Settings/KnownHopController.php \
  app/Http/Controllers/Settings/ChargeModelController.php \
  routes/web.php
do run "php -l $f" >/dev/null; done
echo "[*] PHP lint OK"

echo "[*] Clear caches, reload routes, then restart services"
run "php artisan config:clear"
run "php artisan route:clear"
run "php artisan view:clear"

docker compose restart app web >/dev/null

echo "[+] Done. Visit /settings. If you still see errors, show me: sed -n '1,120p' routes/web.php"
