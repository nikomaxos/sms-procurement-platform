#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step6a: fix Postgres DISTINCT ORDER BY in NetworksController@index"

CTRL=app/Http/Controllers/NetworksController.php
b "$CTRL"

php -r '
$F = "app/Http/Controllers/NetworksController.php";
$c = file_get_contents($F);
if ($c === false) { fwrite(STDERR, "Cannot read $F\n"); exit(1); }

/**
 * Fix 1: string_agg(DISTINCT mcc::text, "," ORDER BY mcc) -> ORDER BY mcc::text
 * Postgres requires ORDER BY items to match the DISTINCT arg expression.
 */
$c = preg_replace(
    "/string_agg\\s*\\(\\s*DISTINCT\\s*\\(?\\s*mcc::text\\s*\\)?\\s*,\\s*\\x27,\\x27\\s*ORDER\\s+BY\\s*mcc\\s*\\)/i",
    "string_agg(DISTINCT (mcc::text), \',\' ORDER BY mcc::text)",
    $c
);

/**
 * (No change needed for pairs aggregator unless it used DISTINCT; ours doesn\'t.)
 */

file_put_contents($F, $c);
'

# Lint & warm caches
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l app/Http/Controllers/NetworksController.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  php artisan route:list | grep -n "networks\.\(index\|edit\|store\|update\)" || true
'
echo "==> Step6a done. Refresh /networks."
