#!/usr/bin/env bash
set -Eeuo pipefail

# Compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> 1) Ensure host .env has a non-empty APP_KEY"
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

echo "==> 2) Write a clean rescue compose (does NOT touch your existing compose)"
mkdir -p docker/nginx
cat > docker/nginx/default.conf <<'NGINX'
server {
  listen 80;
  server_name _;
  root /var/www/html/public;
  index index.php index.html;

  location / {
    try_files $uri $uri/ /index.php?$query_string;
  }

  location ~ \.php$ {
    include fastcgi_params;
    fastcgi_pass app:9000;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
  }

  client_max_body_size 32m;
  sendfile off;
}
NGINX

cat > docker-compose.clean.yml <<'YML'
version: "3.9"
services:
  postgres:
    image: postgres:15
    container_name: sms-platform-postgres-rescue
    environment:
      - POSTGRES_DB=app
      - POSTGRES_USER=app
      - POSTGRES_PASSWORD=secret
    volumes:
      - dbdata_rescue:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app -h localhost"]
      interval: 10s
      timeout: 5s
      retries: 10

  app:
    build: .
    container_name: sms-platform-app-rescue
    working_dir: /var/www/html
    environment:
      - APP_KEY=${APP_KEY}
      - DB_CONNECTION=pgsql
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_DATABASE=app
      - DB_USERNAME=app
      - DB_PASSWORD=secret
    volumes:
      - ./:/var/www/html
      - ./.env:/var/www/html/.env:ro
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "php -r 'echo file_exists(\"public/index.php\")?\"ok\":\"fail\";'"]
      interval: 10s
      timeout: 5s
      retries: 10

  web:
    image: nginx:1.27-alpine
    container_name: sms-platform-web-rescue
    ports:
      - "8080:80"
    depends_on:
      - app
    volumes:
      - ./:/var/www/html:ro
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro

volumes:
  dbdata_rescue:
YML

echo "==> 3) Bring up the clean stack"
$DC -f docker-compose.clean.yml up -d --build

echo "==> 4) Warm Laravel inside the rescue app container"
$DC -f docker-compose.clean.yml exec -T app sh -lc '
  set -Eeuo pipefail
  cd /var/www/html

  # PHP sanity
  php -v | head -n1 || true

  # Composer install if needed (don'"'"'t fail if composer missing in image)
  if [ ! -d vendor ]; then
    if command -v composer >/dev/null 2>&1; then
      composer install --no-interaction --prefer-dist --optimize-autoloader || true
    else
      echo "   - composer not found in image; skipping install [Unverified]"
    fi
  fi

  # Storage/Cache perms
  mkdir -p storage/framework/{cache,sessions,views} bootstrap/cache
  chmod -R ug+rwX storage bootstrap/cache || true

  # Ensure APP_KEY readable
  echo "   - getenv(APP_KEY): $(php -r "echo getenv('APP_KEY')?:'(empty)';")"

  # Rebuild caches
  php artisan optimize:clear || true
  php artisan config:clear   || true
  php artisan route:cache    || true
  php artisan view:cache     || true
  php artisan config:cache   || true

  # Verify config('app.key')
  cat > /tmp/check_app_key.php <<PHP
<?php
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap();
echo config('app.key') ? "CFG_OK\\n" : "CFG_MISS\\n";
PHP
  php /tmp/check_app_key.php || true
  rm -f /tmp/check_app_key.php

  # Optional: ping health route if exists
  if [ -f public/index.php ]; then echo "   - Try: http://localhost:8080/healthz"; fi
'

echo "==> 5) Show URLs"
echo "   - Web:     http://localhost:8080/"
echo "   - Healthz: http://localhost:8080/healthz (if route exists)"
echo "==> Rescue stack is isolated. Your original docker-compose.yml is untouched."
