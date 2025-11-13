#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

echo "==> Ensure required dirs exist on host (with sudo fallback)"
for d in storage/framework/cache storage/framework/sessions storage/framework/views storage/app/carriers bootstrap/cache; do
  mkdir -p "$d" 2>/dev/null || sudo mkdir -p "$d"
done

echo "==> Loosen host perms (dev-safe), sudo fallback if needed"
chmod -R u+rwX,g+rwX storage bootstrap/cache 2>/dev/null || sudo chmod -R u+rwX,g+rwX storage bootstrap/cache

echo "==> Fix perms inside container for the PHP user [Unverified: usually www-data]"
$DC exec -T app bash -lc '
  set -e
  cd /var/www/html
  mkdir -p storage/framework/{cache,sessions,views} storage/app/carriers bootstrap/cache
  # If your FPM user differs, replace www-data with that user/group.
  chown -R www-data:www-data storage bootstrap/cache || true
  chmod -R u+rwX,g+rwX storage bootstrap/cache
'

echo "==> Clear & rebuild caches"
$DC exec -T app bash -lc '
  set -e
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'

echo "==> Done. Visit /countries and /networks. Use the top buttons to Refresh or Fresh import."
