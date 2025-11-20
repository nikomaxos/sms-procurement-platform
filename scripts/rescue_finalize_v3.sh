#!/usr/bin/env bash
set -euo pipefail

# compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
FILE="-f docker-compose.clean.yml"

echo "==> Finalize Laravel in rescue stack (composer, perms, caches, verify)"
$DC $FILE exec -T app sh -c '
set -eu
cd /var/www/html

echo "-> PHP:"
php -v || true

echo "-> APP_KEY (env):"; printenv APP_KEY || true
echo "-> APP_KEY in .env:"; grep -E "^APP_KEY=" .env || true

# Install deps if needed
if [ ! -d vendor ]; then
  composer install --no-interaction --prefer-dist --optimize-autoloader || composer install --no-interaction --prefer-dist
fi

# Perms
mkdir -p storage/framework/{cache,sessions,views} bootstrap/cache
chmod -R 775 storage bootstrap/cache || true

# If .env APP_KEY line exists but is empty, set it from env
if grep -qE "^APP_KEY=$" .env 2>/dev/null; then
  if [ -n "${APP_KEY:-}" ]; then
    sed -i -E "s#^APP_KEY=.*#APP_KEY=${APP_KEY}#g" .env
    echo "-> wrote APP_KEY from env into .env"
  fi
fi

# Clear & rebuild caches
php artisan optimize:clear || true
php artisan config:clear   || true
php artisan route:clear    || true
php artisan view:clear     || true
php artisan config:cache   || true
php artisan route:cache    || true
php artisan view:cache     || true

# Robust verification via temp file
cat > /tmp/check_app_key.php <<PHP
<?php
require __DIR__.'/vendor/autoload.php';
\$app = require __DIR__.'/bootstrap/app.php';
\$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
echo (config('app.key') ? "CFG_OK\n" : "CFG_MISS\n");
PHP
php /tmp/check_app_key.php || true
rm -f /tmp/check_app_key.php
'

echo "==> Make sure you are hitting the rescue stack on port 8080"
$DC $FILE ps

echo "==> Stop the old/original stack so port 8080 belongs to rescue"
( docker compose down --remove-orphans || true )

echo "==> Bring rescue up (alone) on 8080"
$DC $FILE up -d

echo "==> Show routes (confirm app is booted) & tail last errors if any"
$DC $FILE exec -T app php artisan route:list | head -n 60 || true
$DC $FILE exec -T app sh -lc "tail -n 120 storage/logs/laravel.log || true"
