# scripts/fix_admin_middleware_in_routes.sh
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

f="routes/web.php"
cp -a "$f" "$f.bak.$(date +%F_%H-%M-%S)"

# Move ->middleware('admin') from inside the controller array to after the Route::... call arg
php -r '
$f = "routes/web.php";
$s = file_get_contents($f);

/**
 * Fix patterns like:
 *   Route::get("/settings/imap", [ImapSettingsController::class, "edit"]->middleware("admin"))->name(...);
 * to:
 *   Route::get("/settings/imap", [ImapSettingsController::class, "edit"])->middleware("admin")->name(...);
 */
$re = "/(Route::\\s*(?:get|post|put|patch|delete|options|any|match)\\s*\\(\\s*[^,]+,\\s*)\\[([^\\]]+)\\]\\s*->\\s*middleware\\(\\s*[\\\"\\\']admin[\\\"\\\']\\s*\\)/i";
$s  = preg_replace($re, "$1[\\2])->middleware(\'admin\')", $s, -1, $cnt);

if ($cnt === 0) {
  // Be a bit more permissive (handles extra spaces/newlines)
  $re2 = "/(Route::\\s*(?:get|post|put|patch|delete|options|any|match)\\s*\\(\\s*[^,]+,\\s*)\\[([\\s\\S]*?)\\]\\s*->\\s*middleware\\(\\s*[\\\"\\\']admin[\\\"\\\']\\s*\\)/i";
  $s   = preg_replace($re2, "$1[\\2])->middleware(\'admin\')", $s, -1, $cnt2);
}

file_put_contents($f, $s);
'

# Warm caches in the container
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "Fixed: admin middleware chaining on routes. Backup saved as routes/web.php.bak.<timestamp>."
