# scripts/fix_admin_middleware_in_routes_v3.sh
#!/usr/bin/env bash
set -Eeuo pipefail

f="routes/web.php"
test -f "$f" || { echo "Missing $f" >&2; exit 1; }
cp -a "$f" "$f.bak.$(date +%F_%H-%M-%S)"

# Move ->middleware('admin') to the correct place for /settings/imap
perl -0777 -i -pe "
s{
  (Route::\\s*(?:get|post|put|patch|delete|options|any|match)\\s*\\(\\s*['\"]/settings/imap['\"],\\s*)
  \\[\\s*ImapSettingsController::class\\s*,\\s*'edit'\\s*\\]
  \\s*->\\s*middleware\\(\\s*'admin'\\s*\\)
}{
  \$1[ImapSettingsController::class, 'edit'])->middleware('admin')
}gxs;
" \"$f\"

# Warm caches and show the IMAP route row
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache && php artisan route:list | grep -E "settings/imap" || true'

echo "Patched. Backup saved as $f.bak.<timestamp>"
