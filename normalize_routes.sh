#!/usr/bin/env bash
set -Eeuo pipefail

[[ -f routes/web.php ]] || { echo "[x] routes/web.php not found"; exit 1; }

# Backup once
cp -n routes/web.php routes/web.php.bak.$(date +%F_%H%M%S) 2>/dev/null || true

# Write a clean routes file: Breeze defaults + Settings (admin) with FQCN, no duplicate imports
cat > routes/web.php <<'PHP'
<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ProfileController;

Route::get('/', function () { return view('welcome'); });

Route::middleware(['auth'])->group(function () {
    // Dashboard
    Route::view('/dashboard', 'dashboard')->name('dashboard');

    // Profile (Breeze)
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

    // ===== Settings (admin only) =====
    Route::middleware('can:admin')->prefix('settings')->name('settings.')->group(function () {
        Route::get('/', [\App\Http\Controllers\Settings\SettingsController::class, 'index'])->name('index');

        // Users
        Route::resource('users', \App\Http\Controllers\Settings\UserController::class)->except(['show']);

        // Drop-down menus (single index + per-type CRUD)
        Route::get('dropdowns', [\App\Http\Controllers\Settings\RouteTypeController::class, 'index'])->name('dropdowns.index');
        Route::resource('route-types', \App\Http\Controllers\Settings\RouteTypeController::class)->only(['store','update','destroy']);
        Route::resource('known-hops', \App\Http\Controllers\Settings\KnownHopController::class)->only(['store','update','destroy']);
        Route::resource('charge-models', \App\Http\Controllers\Settings\ChargeModelController::class)->only(['store','update','destroy']);

        // Auth logs
        Route::get('logs', [\App\Http\Controllers\Settings\AuthLogController::class, 'index'])->name('logs.index');
    });
});

require __DIR__.'/auth.php';
PHP

# Add Settings link to nav if missing
NAV="resources/views/layouts/navigation.blade.php"
if [[ -f "$NAV" ]] && ! grep -q "route('settings.index')" "$NAV"; then
  cat >> "$NAV" <<'BLADE'

@can('admin')
    <x-nav-link :href="route('settings.index')" :active="request()->routeIs('settings.*')">
        {{ __('Settings') }}
    </x-nav-link>
@endcan
BLADE
fi

echo "[*] Linting..."
php -l routes/web.php >/dev/null && echo "  - routes/web.php OK"

echo "[*] Clearing caches..."
if docker compose ps app >/dev/null 2>&1; then
  docker compose exec -T app php artisan route:clear
  docker compose exec -T app php artisan config:clear
  docker compose exec -T app php artisan view:clear
  docker compose restart app web >/dev/null
else
  php artisan route:clear
  php artisan config:clear
  php artisan view:clear
fi

echo "[+] Done. Visit /settings (and /settings/dropdowns, /settings/users)."
