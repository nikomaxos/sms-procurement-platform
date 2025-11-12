#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Ensure required directories exist (host)"
mkdir -p storage/framework/{cache,data,sessions,testing,views} storage/logs bootstrap/cache

echo "==> Fix host-side minimum perms (so container can adjust further)"
chmod -R u+rwX,g+rwX storage bootstrap/cache || true
find storage bootstrap/cache -type d -exec chmod 775 {} + || true
touch storage/logs/laravel.log && chmod 664 storage/logs/laravel.log || true

echo "==> Fix inside container (ownership + ACLs + caches)"
$DC exec -T app bash -lc '
  set -Eeuo pipefail

  # Discover a sane web user (www-data on Debian-based PHP images; else fallback to current uid/gid)
  if id www-data >/dev/null 2>&1; then
    WEB_U=www-data; WEB_G=www-data
  else
    WEB_U=$(id -un); WEB_G=$(id -gn)
  fi
  echo "   -> using web user: ${WEB_U}:${WEB_G}"

  mkdir -p storage/framework/{cache,data,sessions,testing,views} storage/logs bootstrap/cache

  # Ownership
  chown -R "${WEB_U}:${WEB_G}" storage bootstrap/cache

  # Perms: rw for user & group, dirs g+s so new files inherit group
  find storage bootstrap/cache -type d -exec chmod 2775 {} \;
  find storage bootstrap/cache -type f -exec chmod 0664 {} \;

  # If setfacl is available, grant rwX to WEB_U and also to uid 1000 (common host uid)
  if command -v setfacl >/dev/null 2>&1; then
    setfacl -R -m u:${WEB_U}:rwX -m d:u:${WEB_U}:rwX storage bootstrap/cache || true
    if id -u 1000 >/dev/null 2>&1; then
      setfacl -R -m u:1000:rwX -m d:u:1000:rwX storage bootstrap/cache || true
    fi
  fi

  # Write test
  echo -n "ok" > storage/framework/views/.perm_test && chown ${WEB_U}:${WEB_G} storage/framework/views/.perm_test
  echo "   -> write test: $(cat storage/framework/views/.perm_test)"

  # Rebuild caches
  php artisan optimize:clear || true
  php artisan view:clear || true
  php artisan view:cache || true
  php artisan route:cache || true
'

echo "==> Done."
