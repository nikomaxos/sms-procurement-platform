#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

routes="routes/web.php"
ts="$(date +%F_%H-%M-%S)"

echo "==> 1) Remove legacy controller (if present)"
LEGACY_CTR="app/Http/Controllers/UserManagementController.php"
if [ -f "$LEGACY_CTR" ]; then
  mkdir -p app/Http/Controllers/_legacy
  mv -f "$LEGACY_CTR" "app/Http/Controllers/_legacy/UserManagementController.$ts.php"
  echo "   -> moved legacy controller to _legacy/ (backup kept)"
fi

echo "==> 2) Rewrite routes/web.php to drop any old /settings/users lines and add proper resource"
cp -a "$routes" "$routes.bak.$ts"

# Drop any ad-hoc lines that register /settings/users with any controller
# (keeps other /settings routes like imap, dropdowns intact)
awk '
  BEGIN{skip=0}
  {
    line=$0
    # eliminate single-line definitions that mention /settings/users or settings.users names
    if (line ~ /settings\/users/ || line ~ /settings\.users/ || line ~ /UserManagementController/ || line ~ /UsersManagementController/) {
      # do not print these lines
      next
    }
    print line
  }
' "$routes.bak.$ts" > "$routes"

# Ensure our admin-only resource exists once
if ! grep -q "settings.users.index" "$routes"; then
  cat >> "$routes" <<'PHP'

// Users Management (admin-only via controller middleware)
Route::middleware(['auth'])->prefix('settings')->name('settings.')->group(function () {
    Route::resource('users', \App\Http\Controllers\Settings\UsersManagementController::class)
         ->except(['show'])
         ->names('users');
});
PHP
fi

echo "==> 3) Ensure sidebar uses named route (active highlighting works)"
side="resources/views/partials/sidebar.blade.php"
if [ -f "$side" ]; then
  # Replace Users Management link with named route + admin guard
  awk '
    BEGIN{printed=0}
    {
      print $0
    }
    END{
      # noop; we will just do a simple in-place substitution next
    }
  ' "$side" > "$side.tmp" && mv "$side.tmp" "$side" || true

  # Replace any existing Users Management anchors to the named route
  sed -i \
    -e "s|href=\"{{ *url('/settings/users') *}}\"|href=\"{{ route('settings.users.index') }}\"|g" \
    -e "s|request()->is('settings/users\\*')|request()->routeIs('settings.users.*')|g" \
    "$side" || true

  # Wrap link in admin guard if not already
  if ! grep -q "auth()->user()->role === 'admin'" "$side"; then
    perl -0777 -pe "
      s{
        (\\s*<a\\s+href=\"{{\\s*route\\('settings\\.users\\.index'\\)\\s*}}\"[\\s\\S]*?Users Management[\\s\\S]*?</a>)
      }{
        @if(auth()->check() && auth()->user()->role === 'admin')\n$1\n@endif
      }gs" -i "$side"
  fi
fi

echo "==> 4) Clear caches and rebuild routes"
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan route:cache || true

echo "==> 5) Show the registered users routes"
$DC exec -T app php artisan route:list | sed -n '1,5p; /settings\\/users/p; /settings\\.users/p'

echo "==> Done. Visit /settings/users (as admin)."
