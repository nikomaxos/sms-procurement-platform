# scripts/repair_route_middleware_array.sh
#!/usr/bin/env bash
set -Eeuo pipefail
f="routes/web.php"
test -f "$f" || { echo "Missing $f" >&2; exit 1; }
cp -a "$f" "$f.bak.$(date +%F_%H-%M-%S)"

# Turn:  Route::get('/x', [Ctrl::class, 'm']->middleware('y') ...)
# into:  Route::get('/x', [Ctrl::class, 'm'])->middleware('y') ...
perl -0777 -i -pe '
  s{
    (Route::\s*(?:get|post|put|patch|delete|options|any|match)\s*\(\s*[^,]+,\s*\[[^\]]+\])   # Route(..., [ ... ])
    \s*->\s*middleware\(\s*([^)]+)\s*\)                                                     # ->middleware(...)
  }{$1)->middleware($2)}gsx;
' "$f"

# Quick lint
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php -l routes/web.php && php artisan optimize:clear && php artisan route:cache && php artisan route:list | grep -E "settings/imap|countries|networks" || true'
echo "Done. Backup: $f.bak.<timestamp>"
