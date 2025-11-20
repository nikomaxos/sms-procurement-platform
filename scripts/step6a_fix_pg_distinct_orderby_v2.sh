#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step6a_v2: Fix Postgres DISTINCT ORDER BY (mcc/mnc) in NetworksController@index"

CTRL=app/Http/Controllers/NetworksController.php
PATCH=tools/patches/fix_distinct_orderby.php
mkdir -p tools/patches
b "$CTRL"

cat > "$PATCH" <<'PHP'
<?php
$F = __DIR__ . '/../../app/Http/Controllers/NetworksController.php';
if (!is_file($F)) { fwrite(STDERR, "Missing $F\n"); exit(1); }
$c = file_get_contents($F);
if ($c === false) { fwrite(STDERR, "Cannot read $F\n"); exit(1); }

$repl = [
    // common exact patterns
    "string_agg(DISTINCT mcc::text, ',' ORDER BY mcc)" => "string_agg(DISTINCT mcc::text, ',' ORDER BY mcc::text)",
    'string_agg(DISTINCT mcc::text, "," ORDER BY mcc)' => "string_agg(DISTINCT mcc::text, ',' ORDER BY mcc::text)",
    "string_agg(DISTINCT (mcc::text), ',' ORDER BY mcc)" => "string_agg(DISTINCT (mcc::text), ',' ORDER BY mcc::text)",
    'string_agg(DISTINCT (mcc::text), "," ORDER BY mcc)' => "string_agg(DISTINCT (mcc::text), ',' ORDER BY mcc::text)",

    "string_agg(DISTINCT mnc::text, ',' ORDER BY mnc)" => "string_agg(DISTINCT mnc::text, ',' ORDER BY mnc::text)",
    'string_agg(DISTINCT mnc::text, "," ORDER BY mnc)' => "string_agg(DISTINCT mnc::text, ',' ORDER BY mnc::text)",
    "string_agg(DISTINCT (mnc::text), ',' ORDER BY mnc)" => "string_agg(DISTINCT (mnc::text), ',' ORDER BY mnc::text)",
    'string_agg(DISTINCT (mnc::text), "," ORDER BY mnc)' => "string_agg(DISTINCT (mnc::text), ',' ORDER BY mnc::text)",
];

// Apply simple replacements first
$c2 = strtr($c, $repl);

// Extra safety: regex for minor whitespace variants
$c2 = preg_replace(
    '/string_agg\s*\(\s*DISTINCT\s*\(?\s*mcc::text\s*\)?\s*,\s*[\'"]\s*,\s*[\'"]\s*ORDER\s+BY\s*mcc\s*\)/i',
    "string_agg(DISTINCT (mcc::text), ',\' ORDER BY mcc::text)", // will fix quote below
    $c2
);
$c2 = str_replace("',\'", "','", $c2);
$c2 = preg_replace(
    '/string_agg\s*\(\s*DISTINCT\s*\(?\s*mnc::text\s*\)?\s*,\s*[\'"]\s*,\s*[\'"]\s*ORDER\s+BY\s*mnc\s*\)/i',
    "string_agg(DISTINCT (mnc::text), ',\' ORDER BY mnc::text)",
    $c2
);
$c2 = str_replace("',\'", "','", $c2);

if ($c2 === null) { fwrite(STDERR, "preg_replace error\n"); exit(1); }
if ($c2 === $c) {
    fwrite(STDOUT, "No DISTINCT/ORDER BY mcc|mnc patterns changed (already OK or pattern not found).\n");
} else {
    file_put_contents($F, $c2);
    fwrite(STDOUT, "Patched $F\n");
}
PHP

php "$PATCH"

# Lint & warm caches
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l app/Http/Controllers/NetworksController.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  php artisan route:list | grep -n "networks\.\(index\|edit\|store\|update\)" || true
'

echo "==> Step6a_v2 done. Refresh /networks and test filters & CSV."
