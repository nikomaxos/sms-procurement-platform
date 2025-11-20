#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }

# Choose compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

# Allow overriding service name (default: app)
SERVICE="${SERVICE:-app}"

echo "==> [0] Preconditions"
[ -f docker-compose.yml ] || { echo "docker-compose.yml not found"; exit 1; }

echo "==> [1] Ensure host .env with non-empty APP_KEY"
if [ ! -f .env ]; then cp -f .env.example .env 2>/dev/null || touch .env; echo "   - created .env"; fi
grep -q '^APP_KEY=' .env || { printf "\nAPP_KEY=\n" >> .env; echo "   - appended APP_KEY="; }
APP_KEY_VAL="$(grep -E '^APP_KEY=' .env | cut -d= -f2-)"
if [ -z "$APP_KEY_VAL" ]; then
  APP_KEY_VAL="base64:$(head -c 32 /dev/urandom | base64 | tr -d '\n')"
  sed -i -E "s#^APP_KEY=.*#APP_KEY=${APP_KEY_VAL}#g" .env
  echo "   - generated APP_KEY in host .env"
else
  echo "   - APP_KEY present in host .env"
fi

echo "==> [2] Patch docker-compose.yml with yq (containerized)"
b docker-compose.yml
# Pull yq v4 (small image)
docker pull --quiet mikefarah/yq:4 >/dev/null 2>&1 || true

# Inject environment.APP_KEY = ${APP_KEY}
docker run --rm -v "$PWD":/workdir -w /workdir -e SERVICE -e APP_KEY_VAL \
  mikefarah/yq:4 -i '
    .services[env(SERVICE)].environment
      |= ( . // {} )
    | .services[env(SERVICE)].environment.APP_KEY = "${APP_KEY}"
  ' docker-compose.yml

# Add volumes entry to mount .env into the container (read-only)
docker run --rm -v "$PWD":/workdir -w /workdir -e SERVICE \
  mikefarah/yq:4 -i '
    .services[env(SERVICE)].volumes
      |= ( . // [] | . + ["./.env:/var/www/html/.env:ro"] | unique )
  ' docker-compose.yml

echo "==> [3] Recreate the service so new env/volume apply"
$DC up -d --force-recreate "$SERVICE"

echo "==> [4] Clear caches and verify inside container"
$DC exec -T "$SERVICE" sh -lc '
  set -Eeuo pipefail
  cd /var/www/html || cd /app || pwd

  echo "   - getenv(APP_KEY):"
  php -r "var_export(getenv(\"APP_KEY\")); echo PHP_EOL;"

  php artisan optimize:clear >/dev/null 2>&1 || true
  php artisan config:clear   >/dev/null 2>&1 || true
  php artisan route:cache    >/dev/null 2>&1 || true
  php artisan view:cache     >/dev/null 2>&1 || true
  php artisan config:cache   >/dev/null 2>&1 || true

  cat > /tmp/check_app_key.php <<'"'"'PHP'"'"'
<?php
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
echo config('app.key') ? "CFG_OK\n" : "CFG_MISS\n";
PHP
  php /tmp/check_app_key.php || true
  rm -f /tmp/check_app_key.php
'

echo "==> If verification printed CFG_OK, test /healthz and your pages."
echo "==> Rollback: cp docker-compose.yml.bak.$ts docker-compose.yml && $DC up -d --force-recreate \"$SERVICE\""
