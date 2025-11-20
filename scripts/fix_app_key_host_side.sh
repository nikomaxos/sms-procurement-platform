#!/usr/bin/env bash
set -Eeuo pipefail

# 0) Pick docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Ensure .env exists (HOST) and has a valid APP_KEY"
if [ ! -f .env ]; then
  cp .env.example .env 2>/dev/null || touch .env
  echo "   - created .env on host"
fi

# 1) Ensure APP_KEY= line exists
if ! grep -q '^APP_KEY=' .env; then
  printf "\nAPP_KEY=\n" >> .env
  echo "   - appended APP_KEY= to host .env"
fi

# 2) If empty, generate a fresh base64 key (32 bytes)
cur="$(grep -E '^APP_KEY=' .env | cut -d= -f2-)"
if [ -z "$cur" ]; then
  key="base64:$(head -c 32 /dev/urandom | base64 | tr -d '\n')"
  sed -i -E "s#^APP_KEY=.*#APP_KEY=${key}#g" .env
  echo "   - set APP_KEY in host .env"
else
  echo "   - APP_KEY already present in host .env"
fi

mask="$(grep -E '^APP_KEY=' .env | cut -d= -f2- | sed 's/./*/g')"
echo "   - Host .env APP_KEY: ${mask}"

echo "==> Rebuild caches INSIDE container (do not quote \$DC in single quotes)"
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  cd /var/www/html
  php artisan optimize:clear
  php artisan config:clear
  php artisan route:cache
  php artisan view:cache
  php artisan config:cache
  php -r "echo getenv(\"APP_KEY\")?\"APP_KEY_LOADED\n\":\"APP_KEY_MISSING\n\";"
'
echo "==> Done. Test /healthz and then any page."
