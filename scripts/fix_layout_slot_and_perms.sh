#!/usr/bin/env bash
set -Eeuo pipefail

# 1) Replace any {{ $slot }} / {!! $slot !!} in Blade layouts with @yield('content')
changed=0
while IFS= read -r -d '' f; do
  before="$(sha1sum "$f" | awk '{print $1}')"
  # Replace all common forms
  sed -i -E \
    -e "s/\{\{\s*\$slot\s*\}\}/@yield('content')/g" \
    -e "s/\{\!\!\s*\$slot\s*\!\!\}/@yield('content')/g" \
    -e "s/<\?=\s*\$slot\s*\?>/@yield('content')/g" \
    "$f"
  after="$(sha1sum "$f" | awk '{print $1}')"
  if [ "$before" != "$after" ]; then
    echo "Rewrote: $f"
    changed=$((changed+1))
  fi
done < <(grep -RIlZ --include='*.blade.php' '\$slot' resources/views/layouts || true)

# 2) Ensure a main layout exists; if not, create a minimal one with @yield('content')
LAY='resources/views/layouts/app.blade.php'
if [ ! -f "$LAY" ]; then
  mkdir -p "$(dirname "$LAY")"
  cat > "$LAY" <<'BLADE'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>{{ config('app.name', 'App') }}</title>
</head>
<body>
  @auth
  <nav style="background:#f9fafb;border-bottom:1px solid #e5e7eb;padding:10px 16px">
    <a href="{{ route('dashboard') }}" style="margin-right:12px">Dashboard</a>
    <a href="{{ route('settings.index') }}">⚙️ Settings</a>
  </nav>
  @endauth
  <main class="py-4">
    @yield('content')
  </main>
</body>
</html>
BLADE
  echo "Created minimal layout: $LAY"
fi

# 3) Fix write perms & clear caches inside the PHP container
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

$DC exec -T app sh -lc '
  set -e
  mkdir -p storage/framework/{views,cache,sessions} storage/logs bootstrap/cache
  chown -R www-data:www-data storage bootstrap/cache || true
  chmod -R 0777 storage bootstrap/cache
  rm -f storage/framework/views/* || true
'
$DC exec -T -w /var/www/html app php artisan optimize:clear
$DC exec -T -w /var/www/html app php artisan view:cache || true
$DC exec -T -w /var/www/html app php artisan route:cache || true
$DC exec -T -w /var/www/html app php artisan config:cache || true

echo "==> Done. $changed layout file(s) updated. Open /settings and its subpages."
