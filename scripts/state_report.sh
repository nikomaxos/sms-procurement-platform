#!/usr/bin/env bash
set -Eeuo pipefail

# Always run from repo root if possible
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

ts="$(date +%F_%H-%M-%S)"
out="state_reports/state_${ts}.txt"
mkdir -p state_reports

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

run_app() {
  # Run a command inside the "app" container; warn if fails but keep going
  $DC exec -T app sh -lc "$*" 2>&1 || { echo "[WARN] app container exec failed: $*"; return 1; }
}

{
  echo "=== STATE REPORT ${ts} ==="
  echo "pwd=$(pwd)"
  echo

  echo "---- GIT ----"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    echo "last-commit: $(git log -1 --pretty='%h %ci %s' 2>/dev/null || true)"
    echo "status (porcelain):"
    git status --porcelain=v1 || true
    echo
    echo "tags (last 10):"
    git tag --sort=-creatordate | head -n 10 || true
  else
    echo "Not a git repo"
  fi
  echo

  echo "---- RUNTIME (inside app) ----"
  run_app 'php -v | head -n 1' || true
  run_app 'php artisan --version' || true
  run_app 'composer show laravel/framework | sed -n "1,3p"' || true
  run_app 'composer show webklex/php-imap | sed -n "1,3p"' || true
  echo

  echo "---- ROUTES (filtered) ----"
  run_app 'php artisan route:list --columns=Method,URI,Name,Action | grep -E "countries|networks|carriers/import|settings/imap" || true' || true
  echo

  echo "---- MIGRATIONS ----"
  run_app 'php artisan migrate:status' || true
  echo

  echo "---- DB COUNTS ----"
  run_app "php artisan tinker --execute='echo json_encode([
    \"countries\"=>DB::table(\"countries\")->count(),
    \"country_mccs\"=>DB::table(\"country_mccs\")->count(),
    \"networks\"=>DB::table(\"networks\")->count(),
    \"network_mncs\"=>DB::table(\"network_mncs\")->count()
  ], JSON_PRETTY_PRINT);'" || true
  echo

  echo "---- FILES ----"
  ls -l app/Http/Controllers 2>/dev/null || true
  ls -l resources/views/countries 2>/dev/null || true
  ls -l resources/views/networks 2>/dev/null || true
  echo

  echo "---- routes/web.php (first 120 lines) ----"
  sed -n '1,120p' routes/web.php 2>/dev/null | nl -ba || true
  echo
  echo "---- carriers/import lines in routes/web.php ----"
  nl -ba routes/web.php 2>/dev/null | grep -n "carriers/import" || true

  echo
  echo "=== END ==="
} | tee "$out"

echo
echo "Saved: $out"
