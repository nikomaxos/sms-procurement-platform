#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

ROUTES="routes/web.php"
SETTINGS_VIEW="resources/views/settings/index.blade.php"
SIDEBAR="resources/views/partials/sidebar.blade.php"
NAV="resources/views/partials/nav.blade.php"
ERR403="resources/views/errors/403.blade.php"
UM_CTRL="app/Http/Controllers/Settings/UsersManagementController.php"

ts="$(date +%F_%H-%M-%S)"

echo "==> 1) Remove the /settings route (settings.index) from routes/web.php"
cp -a "$ROUTES" "$ROUTES.bak.$ts"
# Drop any Route::get('/settings', ...) named settings.index (handle single-line)
perl -0777 -i -pe "s~^\\s*Route::get\\(\\s*['\"]/settings['\"]\\s*,[^;]*->name\\(\\s*['\"]settings\\.index['\"]\\s*\\)\\s*;\\s*\\n~~mg" "$ROUTES"

echo "==> 2) Delete the settings hub view"
rm -f "$SETTINGS_VIEW"

echo "==> 3) Remove 'Settings Home' link from sidebar and any nav partial"
if [ -f "$SIDEBAR" ]; then
  cp -a "$SIDEBAR" "$SIDEBAR.bak.$ts"
  # Remove the <li> that links to route('settings.index')
  perl -0777 -i -pe "s~\\n?\\s*<li>\\s*<a\\s+href=\"{{\\s*route\\(\\s*'settings\\.index'\\s*\\)\\s*}}\"[\\s\\S]*?</a>\\s*</li>\\s*\\n?~~i" "$SIDEBAR"
fi

if [ -f "$NAV" ]; then
  cp -a "$NAV" "$NAV.bak.$ts"
  perl -0777 -i -pe "s~\\n?\\s*<a\\s+href=\"{{\\s*route\\(\\s*'settings\\.index'\\s*\\)\\s*}}\"[\\s\\S]*?</a>\\s*\\n?~~i" "$NAV"
fi

echo "==> 4) Replace any route('settings.index') references with route('dashboard') (safe default)"
# Only in app/ and resources/ to avoid vendor
grep -RIl "route('settings.index')" app resources 2>/dev/null | while read -r f; do
  cp -a "$f" "$f.bak.$ts"
  perl -0777 -i -pe "s/route\\(\\s*'settings\\.index'\\s*\\)/route('dashboard')/g" "$f"
done

echo "==> 5) Fix our UsersManagementController non-admin redirect (to dashboard)"
if [ -f "$UM_CTRL" ]; then
  cp -a "$UM_CTRL" "$UM_CTRL.bak.$ts"
  perl -0777 -i -pe "s/redirect\\(\\)\\->route\\(\\s*'settings\\.index'\\s*\\)/redirect()->route('dashboard')/g" "$UM_CTRL"
fi

echo "==> 6) Update 403 error page button (if it pointed to settings.index)"
if [ -f "$ERR403" ]; then
  cp -a "$ERR403" "$ERR403.bak.$ts"
  perl -0777 -i -pe "s/route\\(\\s*'settings\\.index'\\s*\\)/route('dashboard')/g" "$ERR403"
fi

echo "==> 7) Clear & rebuild caches"
$DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rw storage bootstrap/cache'
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan view:clear || true
$DC exec -T app php artisan view:cache || true
$DC exec -T app php artisan route:cache || true

echo "==> Done. /settings hub removed."
echo "   • Any previous references now go to dashboard."
echo "   • Subpages still live: /settings/dropdowns, /settings/imap, /settings/users (admin-guarded)."
