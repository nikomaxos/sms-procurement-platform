#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/carriers_import_nav_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/carriers_import_nav_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR" | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE" | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

NAV_FILE="$ROOT_DIR/resources/views/layouts/navigation.blade.php"

if [ ! -f "$NAV_FILE" ]; then
  echo "ERROR: $NAV_FILE not found" | tee -a "$LOG_FILE"
  exit 1
fi

# -------------------------------------------------------------------
# Backup
# -------------------------------------------------------------------
cp "$NAV_FILE" "$BACKUP_DIR/navigation.blade.php.bak"
echo "==> Backed up navigation.blade.php -> $BACKUP_DIR/navigation.blade.php.bak" | tee -a "$LOG_FILE"

# -------------------------------------------------------------------
# Patch guards: usertype -> is_admin
# -------------------------------------------------------------------
echo "==> Patching admin guard from 'usertype' to 'is_admin'..." | tee -a "$LOG_FILE"

perl -0pi -e "s/auth\\(\\)->user\\(\\)->usertype\\s*===\\s*'admin'/auth()->user()->is_admin/g" "$NAV_FILE"

echo "   - Done patching navigation.blade.php" | tee -a "$LOG_FILE"

# -------------------------------------------------------------------
# Clear & rebuild caches
# -------------------------------------------------------------------
cd "$ROOT_DIR"

if docker compose ps app >/dev/null 2>&1; then
  ARTISAN="docker compose exec -T app php artisan"
else
  ARTISAN="php artisan"
fi

echo "==> Clearing and rebuilding caches via: $ARTISAN" | tee -a "$LOG_FILE"

set +e
$ARTISAN optimize:clear >>"$LOG_FILE" 2>&1
CLEAR_STATUS=$?
$ARTISAN view:cache >>"$LOG_FILE" 2>&1
CACHE_STATUS=$?
set -e

if [ "$CLEAR_STATUS" -ne 0 ] || [ "$CACHE_STATUS" -ne 0 ]; then
  echo "WARN: artisan optimize:clear or view:cache returned non-zero, but continuing. See log for details." | tee -a "$LOG_FILE"
fi

echo "==> Done. If something looks wrong, restore from backup:" | tee -a "$LOG_FILE"
echo "   cp \"$BACKUP_DIR/navigation.blade.php.bak\" \"$NAV_FILE\"" | tee -a "$LOG_FILE"
