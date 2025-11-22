#!/usr/bin/env bash
set -euo pipefail

##
# fix_suppliers_show_route_v1.sh
#
# Holistic fix for the missing `suppliers.show` route.
#
# Background:
# - We added Supplier detail + connections.
# - Views and controller now use route('suppliers.show', $supplier).
# - Existing Route::resource('suppliers', ...) was created without `show`
#   (e.g. ->except(['show'])), so Laravel throws RouteNotFoundException.
#
# This script:
#   - Backs up routes/web.php
#   - If no `suppliers.show` route is defined yet, appends an explicit route:
#       Route::get('/suppliers/{supplier}', [\App\Http\Controllers\SuppliersController::class, 'show'])
#           ->middleware(['auth'])
#           ->name('suppliers.show');
#   - Optionally runs `php -l` inside the app container to sanity-check syntax.
##

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
  pwd
)"
cd "$ROOT_DIR"

ROUTES_FILE="routes/web.php"

if [[ ! -f "$ROUTES_FILE" ]]; then
  echo "ERROR: ${ROUTES_FILE} not found. Are you in the project root?" >&2
  exit 1
fi

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/fix_suppliers_show_route_${STAMP}"

echo "==> Backing up ${ROUTES_FILE} to ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"
cp "${ROUTES_FILE}" "${BACKUP_DIR}/web.php"

# If a suppliers.show route is already present, do nothing
if grep -q "suppliers.show" "$ROUTES_FILE"; then
  echo "==> Route 'suppliers.show' already present in routes/web.php; nothing to add."
else
  echo "==> Appending explicit suppliers.show route with auth middleware"

  cat >> "$ROUTES_FILE" <<'PHP'

/*
|--------------------------------------------------------------------------
| Suppliers show route (detail page)
|--------------------------------------------------------------------------
|
| Ensure that the suppliers.show route exists, even if the original
| Route::resource('suppliers', ...) was created with ->except(['show']).
| Using fully qualified controller class to avoid any missing "use" issues.
|
*/

Route::get('/suppliers/{supplier}', [\App\Http\Controllers\SuppliersController::class, 'show'])
    ->middleware(['auth'])
    ->name('suppliers.show');
PHP
fi

echo "==> Optional: syntax check routes/web.php inside container"
if command -v docker >/dev/null 2>&1; then
  docker compose exec -T app bash -lc 'cd /var/www/html && php -l routes/web.php' || \
    echo "   (php -l reported an issue or container not running; inspect routes/web.php manually if needed)"
fi

echo "==> Done. suppliers.show route ensured."
