#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
LOG="logs/step1g_$ts.log"; mkdir -p logs
exec > >(tee -a "$LOG") 2>&1
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Step1g: country_mccs upsert by mcc (align with unique index) + retry importer"

# Patch importer: country_mccs upsert by mcc only
F=app/Services/CarrierImportService.php
php -l "$F" >/dev/null || true
# Replace any existing updateOrInsert([... 'country_id', 'mcc' ...]) with by 'mcc' only
# (Idempotent patch: handles multiple prior variants)
awk '
  {print}
' "$F" | sed -E '
  s/DB::table\(.\bcountry_mccs\b.\)\.updateOrInsert\(\s*\[\s*.\bcountry_id\b.\s*=>\s*\$country->id\s*,\s*.\bmcc\b.\s*=>\s*\$mcc(Int)?\s*\]\s*,/DB::table('\''country_mccs'\'').updateOrInsert(['\''mcc'\'' => $mccInt],/g;
  s/\$mcc(Int)?\s*=\s*\(int\)\$mcc;/$mccInt = (int)$mcc;/g
' > "$F.tmp" && mv "$F.tmp" "$F"

# Ensure the correct block exists even if sed missed (safe append-once)
if ! grep -q "updateOrInsert(['mcc' =>" "$F"; then
  perl -0777 -pe '
    s|(// country_mccs upsert.*?\n)(.*?\n)|$1.DB::table("\country_mccs")->updateOrInsert([\x27mcc\x27 => $mccInt],[\n    \x27country_id\x27 => $country->id,\n    \x27updated_at\x27 => now(),\n    \x27created_at\x27 => now()\n]);\n$2|s
  ' "$F" > "$F.tmp" && mv "$F.tmp" "$F" || true
fi

# Rebuild + clear caches
$DC exec -T app sh -lc '
  php -l app/Services/CarrierImportService.php
  php artisan optimize:clear
  composer dump-autoload -o
'

# Helper to run small PHP snippets with bootstrapped app
run_php () {
  local BODY="$1"
  $DC exec -T app sh -lc 'cat > /tmp/run_once.php <<'\''PHP'\'' 
<?php
require __DIR__."/vendor/autoload.php";
$app = require __DIR__."/bootstrap/app.php";
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();
'$(printf "%s" "$BODY")'
PHP
php /tmp/run_once.php; rm -f /tmp/run_once.php'
}

echo "==> BEFORE counts"
run_php '
use Illuminate\Support\Facades\DB;
echo json_encode([
  "countries"=>DB::table("countries")->count(),
  "country_mccs"=>DB::table("country_mccs")->count(),
  "networks"=>DB::table("networks")->count(),
  "network_mncs"=>DB::table("network_mncs")->count(),
], JSON_PRETTY_PRINT), PHP_EOL;'

echo "==> Run importer (fresh)"
$DC exec -T app sh -lc "php artisan carriers:import --fresh -v || true"

echo "==> AFTER counts"
run_php '
use Illuminate\Support\Facades\DB;
echo json_encode([
  "countries"=>DB::table("countries")->count(),
  "country_mccs"=>DB::table("country_mccs")->count(),
  "networks"=>DB::table("networks")->count(),
  "network_mncs"=>DB::table("network_mncs")->count(),
], JSON_PRETTY_PRINT), PHP_EOL;'

echo "==> Sample rows"
run_php '
use Illuminate\Support\Facades\DB;
$out = [
  "country_mccs" => DB::table("country_mccs")->orderBy("mcc")->limit(5)->get(),
  "network_mncs" => DB::table("network_mncs")->orderBy("mcc")->orderBy("mnc")->limit(5)->get(),
];
echo json_encode($out, JSON_PRETTY_PRINT), PHP_EOL;'

echo "==> Done. Log: $LOG"
