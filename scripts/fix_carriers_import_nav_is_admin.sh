#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_DIR="$ROOT_DIR/.backups"
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/fix_carriers_import_nav_is_admin_${TS}.log"

echo "==> Running fix_carriers_import_nav_is_admin.sh at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR" | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE" | tee -a "$LOG_FILE"

NAV_FILE="$ROOT_DIR/resources/views/layouts/navigation.blade.php"
if [ ! -f "$NAV_FILE" ]; then
  echo "ERROR: $NAV_FILE not found" | tee -a "$LOG_FILE"
  exit 1
fi

BACKUP_FILE="$BACKUP_DIR/navigation.blade.php.${TS}.bak"
cp "$NAV_FILE" "$BACKUP_FILE"
echo "==> Backed up navigation.blade.php -> $BACKUP_FILE" | tee -a "$LOG_FILE"

# Replace usertype === 'admin' with is_admin in all occurrences
perl -0777 -pi -e "s/auth\(\)->check\(\)\s*&&\s*auth\(\)->user\(\)->usertype\s*===\s*'admin'/auth()->check() && auth()->user()->is_admin/g" "$NAV_FILE"

echo "==> Updated admin guard in navigation.blade.php" | tee -a "$LOG_FILE"

# Try to clear + cache views; if this fails, restore backup
ROLLBACK_NEEDED=0
if docker compose exec -T app php artisan view:clear >>"$LOG_FILE" 2>&1 && \
   docker compose exec -T app php artisan view:cache >>"$LOG_FILE" 2>&1; then
  echo "==> View cache rebuilt OK" | tee -a "$LOG_FILE"
else
  echo "ERROR: artisan view cache commands failed, restoring backup" | tee -a "$LOG_FILE"
  cp "$BACKUP_FILE" "$NAV_FILE"
  ROLLBACK_NEEDED=1
fi

if [ "$ROLLBACK_NEEDED" -eq 1 ]; then
  echo "==> Restored $NAV_FILE from $BACKUP_FILE due to failure" | tee -a "$LOG_FILE"
  exit 1
fi

echo "==> Done. Carriers Import link should now be visible for is_admin=true users." | tee -a "$LOG_FILE"
echo "Backup: $BACKUP_FILE" | tee -a "$LOG_FILE"
