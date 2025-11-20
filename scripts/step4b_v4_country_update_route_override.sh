#!/usr/bin/env bash
set -Eeuo pipefail
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$(date +%F_%H-%M-%S)" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Step4b_v4: replace countries.update route with proxy"

R=routes/web.php
UP=app/Http/Controllers/CountryUpdateProxy.php

# Sanity check
if [ ! -f "$UP" ]; then
  echo "CountryUpdateProxy is missing. Aborting." >&2
  exit 1
fi

# Backup and remove any existing countries.update route lines
b "$R"
# This removes any lines that name the countries.update route (even if spaced/quoted differently)
sed -i '/countries[.]update/d' "$R"

# Append our proxy route (auth-protected)
cat >> "$R" <<'PHP'

// ---- override countries.update to use CountryUpdateProxy ----
Route::middleware(['auth'])->group(function () {
    Route::put('/countries/{country}', [\App\Http\Controllers\CountryUpdateProxy::class, '__invoke'])
        ->name('countries.update');
});
PHP

# Rebuild route cache and show the target
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php artisan optimize:clear
  php artisan route:cache
  php artisan route:list | grep -n "countries.update" || true
'
echo "==> Done."
