#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

ts="$(date +%F_%H-%M-%S)"
routes="routes/web.php"

echo "==> 1) Move legacy controller if present"
LEGACY_CTR="app/Http/Controllers/UserManagementController.php"
if [ -f "$LEGACY_CTR" ]; then
  mkdir -p app/Http/Controllers/_legacy
  mv -f "$LEGACY_CTR" "app/Http/Controllers/_legacy/UserManagementController.$ts.php"
  echo "   -> moved legacy controller to _legacy/ (backup kept)"
fi

echo "==> 2) Rewrite routes/web.php: drop any old /settings/users lines, keep everything else"
cp -a "$routes" "$routes.bak.$ts"

# Remove any single-line route registrations that mention settings/users or those controller names
# (keeps unrelated routes intact)
awk '
  {
    line=$0
    if (line ~ /Route::/ &&
        (line ~ /settings[\/. ]*users/ || line ~ /UserManagementController/ || line ~ /UsersManagementController/)) {
      # drop this offending route line
      next
    }
    print line
  }
' "$routes.bak.$ts" > "$routes.tmp.1"

# Remove any empty tailing lines we may have created
awk 'NF{print}' "$routes.tmp.1" > "$routes.tmp.2"

# Append our canonical resource once if not already present
if ! grep -q "Settings\\\\UsersManagementController" "$routes.tmp.2"; then
  cat >> "$routes.tmp.2" <<'PHP'

// ==== BEGIN USERS MANAGEMENT (AUTO) ====
Route::middleware(['auth'])->prefix('settings')->name('settings.')->group(function () {
    Route::resource('users', \App\Http\Controllers\Settings\UsersManagementController::class)
         ->except(['show'])
         ->names('users');
});
// ==== END USERS MANAGEMENT (AUTO) ====
PHP
fi

mv -f "$routes.tmp.2" "$routes"
rm -f "$routes.tmp.1"

echo "==> 3) Ensure sidebar uses the named route and admin guard"
SIDE="resources/views/partials/sidebar.blade.php"
if [ -f "$SIDE" ]; then
  # url('/settings/users') -> route('settings.users.index')
  sed -i -E "s|href=\"{{ *url\\('/settings/users'\\) *}}\"|href=\"{{ route('settings.users.index') }}\"|g" "$SIDE" || true
  # request()->is('settings/users*') -> request()->routeIs('settings.users.*')
  sed -i -E "s|request\\(\\)->is\\('settings/users\\*'\\)|request()->routeIs('settings.users.*')|g" "$SIDE" || true

  # Wrap link in admin guard if not already
  if ! grep -q "auth()->user()->role === 'admin'" "$SIDE"; then
    # Insert guard around the first Users Management link
    awk '
      BEGIN{done=0}
      {
        if (!done && $0 ~ /Users Management/ && $0 ~ /route\\(\x27settings.users.index\x27\\)/) {
          print "@if(auth()->check() && auth()->user()->role === \x27admin\x27)"
          print $0
          print "@endif"
          done=1
        } else {
          print $0
        }
      }
    ' "$SIDE" > "$SIDE.tmp" && mv "$SIDE.tmp" "$SIDE"
  fi
fi

echo "==> 4) Rebuild autoload & clear/recache routes"
$DC exec -T app composer dump-autoload -o
$DC exec -T app php artisan route:clear
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan route:cache

echo "==> 5) Show registered Users Management routes"
$DC exec -T app php artisan route:list | awk '
  BEGIN{header=0}
  /Method/ && /URI/ && /Name/ {header=1; print; next}
  header && /settings\\/users/ {print}
'

echo "==> Done. Open /settings/users as admin."
