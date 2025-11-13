# scripts/fix_routes_imap_admin.sh
#!/usr/bin/env bash
set -Eeuo pipefail
f="routes/web.php"
test -f "$f" || { echo "Missing $f" >&2; exit 1; }
cp -a "$f" "$f.bak.$(date +%F_%H-%M-%S)"

# 1) Remove a single extra ')' between ->middleware(...) and ->name(...)
perl -0777 -i -pe "
  s{
    (Route::\\s*(?:get|post|put|patch|delete|options|any|match)\\s*\\(\\s*['\"]/settings/imap['\"].*?->middleware\\([^)]*\\))\\)\\s*(->name\\([^)]*\\)\\s*;)
  }{\$1 \$2}gsx;
" "$f"

# 2) If the IMAP route exists but lacks ->middleware('admin'), insert it before ->name(...)
perl -0777 -i -pe "
  s{
    (Route::\\s*(?:get|post|put|patch|delete|options|any|match)\\s*\\(\\s*['\"]/settings/imap['\"].*?\\])\\s*(->name\\([^)]*\\)\\s*;)
  }{\$1->middleware('admin') \$2}gsx
" "$f"

# Quick lint & recache
if docker compose version >/dev/null 2>&1; then DC='docker compose'; else DC='docker-compose'; fi
$DC exec -T app sh -lc 'php -l routes/web.php && php artisan optimize:clear && php artisan route:cache && php artisan route:list | grep -E "settings/imap|countries|networks" || true'
echo "Patched. Backup created: $f.bak.<timestamp>"
