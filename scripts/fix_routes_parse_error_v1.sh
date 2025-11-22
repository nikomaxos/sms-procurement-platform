#!/usr/bin/env bash
set -euo pipefail

##
# fix_routes_parse_error_v1.sh
#
# Fixes the "Unclosed '(' on line XXX" parse error in routes/web.php
# caused by the nested SupplierConnections Route::middleware([...])->group(...)
# missing its final ');'.
#
# It:
#  - Backs up routes/web.php
#  - Replaces the last standalone "}" at the end of the file with "});"
##

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
  pwd
)"
cd "$ROOT_DIR"

ROUTES_FILE="routes/web.php"

if [[ ! -f "$ROUTES_FILE" ]]; then
  echo "ERROR: ${ROUTES_FILE} not found. Are you in the project root?" >&2
  exit 1
fi

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/fix_routes_parse_error_${STAMP}"

echo "==> Backing up ${ROUTES_FILE} to ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"
cp "${ROUTES_FILE}" "${BACKUP_DIR}/web.php"

echo "==> Patching ${ROUTES_FILE} (closing final Route::middleware group)"

# Replace the last "\n}\n" (end of file) with "\n});\n"
perl -0pi -e 's/\n}\s*$/\n});\n/' "$ROUTES_FILE"

echo "==> Done. Syntax patch applied."

# Optional: quick syntax check inside the app container (ignore failure if containers are down)
if command -v docker >/dev/null 2>&1; then
  echo "==> Running php -l routes/web.php inside app container (optional syntax check)..."
  docker compose exec -T app bash -lc 'cd /var/www/html && php -l routes/web.php' || \
    echo "   (php -l failed or container not running; check manually if needed)"
fi

echo "==> Finished. If php -l reported no syntax errors, refresh the app in your browser."
