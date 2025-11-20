#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
LOG="logs/step1e_v2_$ts.log"; mkdir -p logs
exec > >(tee -a "$LOG") 2>&1
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Step1e_v2: retry importer + robust BEFORE/AFTER diagnostics (no fragile quoting)"

# 0) Ensure service compiles (we keep your current content; no rewrite)
php -l app/Services/CarrierImportService.php || true

# helper to run a one-off PHP inside the container with full Laravel bootstrap
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

echo "==> Possible duplicates BEFORE (top 15)"
run_php '
use Illuminate\Support\Facades\DB;
$rows = DB::select("SELECT country_id, LOWER(name) AS lname, COUNT(*) c FROM networks GROUP BY country_id, lname HAVING COUNT(*)>1 ORDER BY c DESC LIMIT 15");
echo json_encode($rows, JSON_PRETTY_PRINT), PHP_EOL;
'

echo "==> Row counts BEFORE"
run_php '
use Illuminate\Support\Facades\DB;
echo json_encode([
  "countries"=>DB::table("countries")->count(),
  "country_mccs"=>DB::table("country_mccs")->count(),
  "networks"=>DB::table("networks")->count(),
  "network_mncs"=>DB::table("network_mncs")->count(),
], JSON_PRETTY_PRINT), PHP_EOL;
'

echo "==> Run importer (fresh)"
$DC exec -T app sh -lc "php artisan carriers:import --fresh -v || true"

echo "==> Row counts AFTER"
run_php '
use Illuminate\Support\Facades\DB;
echo json_encode([
  "countries"=>DB::table("countries")->count(),
  "country_mccs"=>DB::table("country_mccs")->count(),
  "networks"=>DB::table("networks")->count(),
  "network_mncs"=>DB::table("network_mncs")->count(),
], JSON_PRETTY_PRINT), PHP_EOL;
'

echo "==> Possible duplicates AFTER (top 15)"
run_php '
use Illuminate\Support\Facades\DB;
$rows = DB::select("SELECT country_id, LOWER(name) AS lname, COUNT(*) c FROM networks GROUP BY country_id, lname HAVING COUNT(*)>1 ORDER BY c DESC LIMIT 15");
echo json_encode($rows, JSON_PRETTY_PRINT), PHP_EOL;
'

echo "==> Sample of populated links (if any)"
run_php '
use Illuminate\Support\Facades\DB;
$out = [
  "country_mccs" => DB::table("country_mccs")->limit(5)->get(),
  "network_mncs" => DB::table("network_mncs")->limit(5)->get(),
];
echo json_encode($out, JSON_PRETTY_PRINT), PHP_EOL;
'

echo "==> Done. Log: $LOG"
