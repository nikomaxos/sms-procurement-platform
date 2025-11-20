#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Ensure league/iso3166 is available (and fix git safe.directory)"
$DC exec -T app sh -lc '
  set -eu
  cd /var/www/html
  git config --global --add safe.directory /var/www/html || true
  # composer require (no --no-dev flag here)
  composer require league/iso3166:^3 -n --prefer-dist --no-progress
'

echo "==> Seed countries from ISO-3166 (~249 rows, idempotent)"
$DC exec -T app sh -lc '
  set -eu
  cd /var/www/html
  cat > /tmp/seed_countries.php <<PHP
<?php
require __DIR__."/vendor/autoload.php";
\$app = require __DIR__."/bootstrap/app.php";
\$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use Illuminate\Support\Facades\DB;
use League\ISO3166\ISO3166;

\$rows = (new ISO3166())->all();
DB::transaction(function() use (\$rows) {
  foreach (\$rows as \$r) {
    \$name   = \$r["name"]   ?? null;
    \$alpha2 = strtoupper(\$r["alpha2"] ?? "");
    if (!\$name || !preg_match("/^[A-Z]{2}$/", \$alpha2)) { continue; }
    DB::table("countries")->updateOrInsert(
      ["iso2" => \$alpha2],
      ["name" => \$name, "updated_at" => now(), "created_at" => now()]
    );
  }
});
echo "Seeded countries\\n";
PHP
  php /tmp/seed_countries.php
  rm -f /tmp/seed_countries.php
'

echo "==> Show count"
$DC exec -T postgres bash -lc 'export PGPASSWORD=secret; psql -U app -d app -c "SELECT COUNT(*) AS countries FROM countries;"'
