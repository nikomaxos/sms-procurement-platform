#!/usr/bin/env bash
set -Eeuo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

CTRL="app/Http/Controllers/NetworksController.php"
bak="$CTRL.bak.$(date +%F_%H-%M-%S)"
cp -a "$CTRL" "$bak" 2>/dev/null || true

php -r '
$f = "app/Http/Controllers/NetworksController.php";
$s = file_get_contents($f);
if($s===false){fwrite(STDERR,"Missing $f\n"); exit(1);}
$fixed = preg_replace(
    # replace any previous MIN concat without a FROM clause with a proper correlated subquery
    "/orderByRaw\\s*\\(\\s*\\(\\s*select\\s+coalesce\\(\\s*min\\([^)]*\\)\\s*,\\s*\\'\\'\\)\\s*\\)\\s*asc\\s*\\)\\s*;/i",
    "->orderByRaw(\"(select coalesce(min(nm.mcc::text || nm.mnc::text), \\'\\') from network_mncs nm where nm.network_id = networks.id) asc\");",
    $s
);
# If the above pattern didn’t match, try inserting the correct orderByRaw after the countries.name sort
if ($fixed === $s) {
    $fixed = preg_replace(
        "/->orderBy\\(\\s*\\'countries\\.name\\'\\s*,\\s*\\'asc\\'\\s*\\)\\s*;/i",
        "->orderBy('countries.name','asc')\n          ->orderByRaw(\"(select coalesce(min(nm.mcc::text || nm.mnc::text), \\'\\') from network_mncs nm where nm.network_id = networks.id) asc\");",
        $s
    );
}
if ($fixed===null){fwrite(STDERR,\"Regex error\\n\"); exit(1);}
file_put_contents($f,$fixed);
'

# warm caches
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "Patched NetworksController ordering. Backup: $bak"
