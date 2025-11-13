# scripts/fix_admin_middleware_in_routes_v2.sh
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

f="routes/web.php"
test -f "$f" || { echo "Missing $f" >&2; exit 1; }
cp -a "$f" "$f.bak.$(date +%F_%H-%M-%S)"

# Move ->middleware('admin') from INSIDE the controller array to AFTER the Route() call
perl -0777 -i -pe '
  s{
    (Route::\s*(?:get|post|put|patch|delete|options|any|match)\s*\(\s*[^,]+,\s*) # Route head
    \s*\[([^\]]*?)\]\s*                           # [Controller::class, "method"]
    ->\s*middleware\(\s*([\'"])admin\3\s*\)       # misplaced ->middleware("admin")
  }{$1\[$2])->middleware('\''admin'\'')}gis;

  # Clean up any accidental doubled brackets
  s/\]\]\s*->\s*middleware/\])->middleware/g;
' "$f"

# Warm caches in container
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "Fixed admin middleware chaining. Backup: $f.bak.<timestamp>"
