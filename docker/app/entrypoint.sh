#!/usr/bin/env bash
set -Eeuo pipefail

cd /var/www/html

# make sure runtime dirs are writable
mkdir -p storage/framework/{cache,sessions,views} storage/logs bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache || true

# PHP-FPM
exec php-fpm -F
