#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

R="routes/web.php"
b "$R"

# Remove any broken/duplicate carriers/import lines
sed -i '/carriers\/import/d' "$R"

# Append a clean, fully-qualified, auth-protected block (no stray brackets)
cat >> "$R" <<'PHP'

// ---- Carriers import routes (round18 fixed) ----
Route::middleware(['auth'])->group(function () {
    Route::view('/carriers/import', 'carriers.import')->name('carriers.import.form');
    Route::post(
        '/carriers/import',
        [\App\Http\Controllers\CarriersImportController::class, 'run']
    )->name('carriers.import');
});
PHP

# Lint & warm caches inside app container
$DC exec -T app sh -lc '
  php -l routes/web.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  php artisan route:list | grep -E "carriers/import|^ +GET|^ +POST" -n || true
'
echo "OK: routes patched and caches rebuilt."
