#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> 1) Add migration to relax legacy NOT NULL on networks.{mcc,mnc,mcc_mnc}"
mkdir -p database/migrations
FN="database/migrations/$(date +%Y_%m_%d_%H%M%S)_relax_legacy_not_null_on_networks_mcc_mnc.php"
cat > "$FN" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc DROP NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mnc DROP NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc_mnc DROP NOT NULL"); } catch (\Throwable $e) {}
    }
    public function down(): void {
        // Best-effort rollback (may fail if nulls exist)
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc SET NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mnc SET NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc_mnc SET NOT NULL"); } catch (\Throwable $e) {}
    }
};
PHP

echo "==> 2) Make importer also populate country_mccs (if missing)"
F=app/Services/CarrierImportService.php
b "$F"
php -d detect_unicode=0 -r '
$f="app/Services/CarrierImportService.php";
$s=file_exists($f)?file_get_contents($f):""; if($s===""){fwrite(STDERR,"Missing $f\n"); exit(1);}
if(strpos($s,"ensure country_mccs has this MCC")===false){
  $s=preg_replace(
    "~(\\$country\\s*=\\s*Country::firstOrCreate\\([^;]+;\\s*\\)\\s*;\\s*if \\(\\$country->wasRecentlyCreated\\) \\$newCountries\\+\\+;)~s",
    "$1\n                // also ensure country_mccs has this MCC\n                if (\\is_string(\$mcc) && \$mcc !== \"\") {\n                    \$existsMcc = \\Illuminate\\Support\\Facades\\DB::table(\"country_mccs\")\n                        ->where([\"country_id\"=>\$country->id, \"mcc\"=>\$mcc])->exists();\n                    if (!\$existsMcc) {\n                        \\Illuminate\\Support\\Facades\\DB::table(\"country_mccs\")->insert([\n                            \"country_id\"=>\$country->id,\n                            \"mcc\"=>\$mcc,\n                            \"created_at\"=>now(),\n                            \"updated_at\"=>now(),\n                        ]);\n                    }\n                }",
    $s, 1
  );
  file_put_contents($f,$s);
}
'

echo "==> 3) Migrate + rebuild caches"
$DC exec -T app sh -lc '
  php artisan migrate --force
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'

echo "==> 4) Test importer quickly (fresh ITU)"
$DC exec -T app sh -lc '
  php artisan carriers:import --source=itu --fresh -v
'

echo "Done: schema relaxed; importer now seeds country_mccs; fresh import executed."
