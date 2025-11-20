#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
FILE="-f docker-compose.clean.yml"

echo "==> Create admin user inside rescue app container"
$DC $FILE exec -T app sh -lc '
  set -eu
  cd /var/www/html
  cat > seed_admin.php <<PHP
<?php
require __DIR__."/vendor/autoload.php";
\$app = require __DIR__."/bootstrap/app.php";
\$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Models\User;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Hash;

if (!Schema::hasTable("users")) { fwrite(STDERR, "users table missing\n"); exit(1); }

\$u = User::where("email","admin@example.com")->first();
if (!\$u) { \$u = new User(); \$u->name = "Admin"; \$u->email = "admin@example.com"; }
\$u->password = Hash::make("admin123");
if (Schema::hasColumn("users","email_verified_at")) { \$u->email_verified_at = now(); }
if (Schema::hasColumn("users","is_admin"))        { \$u->is_admin = true; }
if (Schema::hasColumn("users","role"))            { \$u->role = "admin"; }
\$u->save();
echo "ADMIN_OK\n";
PHP
  php seed_admin.php && rm -f seed_admin.php
'
echo "==> Done. Try login: admin@example.com / admin123"
