#!/usr/bin/env bash
set -Eeuo pipefail
# pick docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Ensure APP_KEY + caches + perms"
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  cd /var/www/html

  # 1) Ensure .env exists
  if [ ! -f .env ]; then
    cp .env.example .env 2>/dev/null || touch .env
    echo "   - created .env"
  fi

  # 2) Create APP_KEY if missing/empty
  if ! grep -q "^APP_KEY=" .env || [ -z "$(grep -E "^APP_KEY=" .env | cut -d= -f2-)" ]; then
    echo "   - generating APP_KEY"
    php artisan key:generate --force
  fi

  # 3) Show masked key (για επιβεβαίωση)
  echo "   - APP_KEY: $(grep -E "^APP_KEY=" .env | cut -d= -f2- | sed "s/./*/g")"

  # 4) Ensure dirs & perms
  mkdir -p storage/framework/{cache,sessions,views}
  chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
  chmod -R ug+rwX storage bootstrap/cache || true

  # 5) Clear/rebuild caches
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  php artisan config:cache
'
echo "==> Done. Now reload the app (try /healthz first)."
