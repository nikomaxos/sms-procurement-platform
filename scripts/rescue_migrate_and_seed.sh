#!/usr/bin/env bash
set -euo pipefail

# compose alias + rescue file
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
FILE="-f docker-compose.clean.yml"

echo "==> Check DB env seen by app"
$DC $FILE exec -T app sh -lc 'cd /var/www/html && egrep -i "^(DB_CONNECTION|DB_HOST|DB_PORT|DB_DATABASE|DB_USERNAME|DB_PASSWORD)=" .env || true'

echo "==> Run migrations"
$DC $FILE exec -T app sh -lc 'cd /var/www/html && php artisan migrate --force'

echo "==> Seed/ensure admin user"
$DC $FILE exec -T app sh -lc '
  set -e
  cd /var/www/html
  cat > /tmp/seed_admin.php <<PHP
<?php
require __DIR__."/vendor/autoload.php";
\$app = require __DIR__."/bootstrap/app.php";
\$app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap();

use App\\Models\\User;
use Illuminate\\Support\\Facades\\Schema;
use Illuminate\\Support\\Facades\\Hash;

if (!Schema::hasTable("users")) { fwrite(STDERR, "users table missing\\n"); exit(1); }

\$u = User::where("email","admin@example.com")->first();
if (!\$u) {
  \$u = new User();
  \$u->name = "Admin";
  \$u->email = "admin@example.com";
}
\$u->password = Hash::make("admin123");
if (Schema::hasColumn("users","email_verified_at")) { \$u->email_verified_at = now(); }
\$u->save();
echo "ADMIN_OK\\n";
PHP
  php /tmp/seed_admin.php
  rm -f /tmp/seed_admin.php
'

echo "==> Clear/rebuild caches (optional)"
$DC $FILE exec -T app sh -lc 'cd /var/www/html && php artisan optimize:clear && php artisan config:cache && php artisan route:cache && php artisan view:cache'

echo "==> Done. Try login: admin@example.com / admin123"
