#!/usr/bin/env bash
set -Eeuo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc '
  set -e
  install -d -m 0777 storage/framework/cache storage/framework/sessions storage/framework/views storage/app/carriers bootstrap/cache
  # prefer chown if allowed (some images allow it), else chmod fallback:
  chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
  chmod -R 0777 storage bootstrap/cache
  touch storage/framework/views/.perm_test && echo ok > storage/framework/views/.perm_test
  php artisan optimize:clear
'
echo "Perms fixed inside container."
