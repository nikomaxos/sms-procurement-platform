#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"

# Compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
SERVICE="${SERVICE:-app}"

echo "==> [0] Preconditions"
[ -f docker-compose.yml ] || { echo "docker-compose.yml not found"; exit 1; }

latest_bak() { ls -1t docker-compose.yml.bak.* 2>/dev/null | head -n1 || true; }

echo "==> [1] If compose file is broken, restore the latest backup"
if ! docker run --rm -v "$PWD":/work -w /work mikefarah/yq:4 -oy '.' docker-compose.yml >/dev/null 2>&1; then
  bak="$(latest_bak)"
  if [ -n "$bak" ]; then
    echo "   - Restoring from $bak"
    cp -f "$bak" docker-compose.yml
  else
    echo "   - No backup found. Please paste docker-compose.yml here or set up a fresh one."
    exit 2
  fi
fi

echo "==> [2] Ensure host .env has a non-empty APP_KEY"
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

echo "==> [3] Create/patch docker-compose.override.yml (non-destructive)"
# This file is read automatically by Compose alongside docker-compose.yml
cat > docker-compose.override.yml <<YML
services:
  ${SERVICE}:
    environment:
      APP_KEY: \${APP_KEY}
    volumes:
      - ./.env:/var/www/html/.env:ro
YML

# Validate merged config and list services
echo "==> [4] Validate merged config"
$DC config >/dev/null

echo "==> [5] Recreate ${SERVICE} to pick up env & mount"
$DC up -d --force-recreate "${SERVICE}"

echo "==> [6] Clear caches and verify inside the container"
$DC exec -T "${SERVICE}" sh -lc '
  set -Eeuo pipefail
  cd /var/www/html || cd /app || pwd

  echo -n "   - getenv(APP_KEY): "
  php -r "echo getenv(\"APP_KEY\")?:\"(empty)\"; echo PHP_EOL;"

  php artisan optimize:clear >/dev/null 2>&1 || true
  php artisan config:clear   >/dev/null 2>&1 || true
  php artisan route:cache    >/dev/null 2>&1 || true
  php artisan view:cache     >/dev/null 2>&1 || true
  php artisan config:cache   >/dev/null 2>&1 || true

  cat > /tmp/check_app_key.php <<PHP
<?php
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap();
echo config('app.key') ? "CFG_OK\\n" : "CFG_MISS\\n";
PHP
  php /tmp/check_app_key.php || true
  rm -f /tmp/check_app_key.php
'

echo "==> If you see CFG_OK, test /healthz and normal pages."
echo "==> If your service name is not '${SERVICE}', re-run: SERVICE=<name> bash scripts/recover_compose_and_inject_appkey.sh"
