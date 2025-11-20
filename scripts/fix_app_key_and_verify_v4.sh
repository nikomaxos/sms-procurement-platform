#!/usr/bin/env bash
set -Eeuo pipefail

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> [1/3] Ensure host .env + APP_KEY"
if [ ! -f .env ]; then
  cp -f .env.example .env 2>/dev/null || touch .env
  echo "    - created .env on host"
fi
if ! grep -q '^APP_KEY=' .env; then
  printf "\nAPP_KEY=\n" >> .env
  echo "    - appended APP_KEY= to host .env"
fi
cur="$(grep -E '^APP_KEY=' .env | cut -d= -f2-)"
if [ -z "$cur" ]; then
  key="base64:$(head -c 32 /dev/urandom | base64 | tr -d '\n')"
  sed -i -E "s#^APP_KEY=.*#APP_KEY=${key}#g" .env
  echo "    - set APP_KEY in host .env"
else
  echo "    - APP_KEY already present in host .env"
fi
mask="$(grep -E '^APP_KEY=' .env | cut -d= -f2- | sed 's/./*/g')"
echo "    - Host .env APP_KEY: ${mask}"

echo "==> [2/3] Clear & rebuild caches inside container"
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  cd /var/www/html
  php artisan optimize:clear
  php artisan config:clear
  php artisan route:cache
  php artisan view:cache
  php artisan config:cache
'

echo "==> [3/3] Verify from within Laravel (config('app.key'))"
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  cd /var/www/html
  cat > check_app_key.php <<PHP
<?php
require __DIR__."/vendor/autoload.php";
$app = require __DIR__."/bootstrap/app.php";
$app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap();
$cfg = config("app.key");
echo $cfg ? "CFG_OK\\n" : "CFG_MISS\\n";
PHP
  php check_app_key.php
  rm -f check_app_key.php
'
