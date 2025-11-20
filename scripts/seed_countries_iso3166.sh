#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

# 1) Ensure the package exists
$DC exec -T app sh -lc '
  cd /var/www/html
  if ! php -r "class_exists(\"League\\\ISO3166\\\ISO3166\")?exit(0):exit(1);" 2>/dev/null; then
    composer require league/iso3166:^3 --no-interaction --no-dev --prefer-dist
  fi
'

# 2) Seed (upsert on iso2)
$DC exec -T app sh -lc '
  cd /var/www/html
  php -r "
    require __DIR__ . \"/vendor/autoload.php\";
    \$app = require __DIR__ . \"/bootstrap/app.php\";
    \$app->make(Illuminate\\\Contracts\\\Console\\\Kernel::class)->bootstrap();
    use Illuminate\\\Support\\\Facades\\\DB;
    use League\\\ISO3166\\\ISO3166;

    \$rows = (new ISO3166())->all();
    DB::transaction(function() use(\$rows){
      foreach(\$rows as \$r){
        \$name = \$r['name'] ?? null;
        \$alpha2 = strtoupper(\$r['alpha2'] ?? '');
        if(!\$name || !preg_match('/^[A-Z]{2}\$/', \$alpha2)){ continue; }
        DB::table('countries')->updateOrInsert(
          ['iso2' => \$alpha2],
          ['name' => \$name, 'updated_at'=>now(), 'created_at'=>now()]
        );
      }
    });
    echo \"Seeded countries from ISO3166\\n\";
  "
'

# 3) Show counts
$DC exec -T postgres bash -lc 'export PGPASSWORD=secret; psql -U app -d app -c "SELECT count(*) AS countries FROM countries;"'
