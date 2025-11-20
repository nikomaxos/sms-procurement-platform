#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Retire any legacy carriers:import command files"
# Move aside anything that either declares the same signature or a likely legacy class name
while IFS= read -r -d '' f; do b "$f"; mv "$f" "$f.legacy.$ts.off"; echo "moved: $f"; done \
  < <(grep -RIlzo --include='*.php' -e "carriers:import" -e "class[[:space:]]\+ImportCarriers" app/Console/Commands 2>/dev/null || true)

# Remove explicit ImportCarriers reference from Kernel (if any)
if [ -f app/Console/Kernel.php ]; then
  b app/Console/Kernel.php
  sed -i '/ImportCarriers::class/d' app/Console/Kernel.php || true
fi

echo "==> Autoload refresh"
$DC exec -T app sh -lc 'composer dump-autoload -o'

echo "==> Which carriers:import is registered now?"
$DC exec -T app sh -lc 'php artisan help carriers:import || true'

echo "==> Quick connectivity check from PHP (no curl needed)"
$DC exec -T app sh -lc "php -r '\
\$u=\"https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json\"; \
echo (@file_get_contents(\$u)!==false)?\"REMOTE_OK\n\":\"REMOTE_FAIL\n\"; \
'"

echo "==> Run fresh import with the new command"
$DC exec -T app sh -lc 'php artisan carriers:import --fresh -v || true'

echo "==> Row counts after import"
$DC exec -T app sh -lc 'php artisan tinker --execute='"'"'echo json_encode([
  "countries"=>DB::table("countries")->count(),
  "country_mccs"=>DB::table("country_mccs")->count(),
  "networks"=>DB::table("networks")->count(),
  "network_mncs"=>DB::table("network_mncs")->count()
], JSON_PRETTY_PRINT);'"'"''
