#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/fix_nav_admin_flag_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/fix_nav_admin_flag_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR" | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE" | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

NAV_FILE="$ROOT_DIR/resources/views/layouts/navigation.blade.php"

if [ ! -f "$NAV_FILE" ]; then
  echo "ERROR: $NAV_FILE not found" | tee -a "$LOG_FILE"
  exit 1
fi

BACKUP_NAV="$BACKUP_DIR/navigation.blade.php.bak"
cp "$NAV_FILE" "$BACKUP_NAV"
echo "==> Backed up navigation to $BACKUP_NAV" | tee -a "$LOG_FILE"

on_error() {
  echo "ERROR: ${SCRIPT_NAME} failed, restoring backup nav" | tee -a "$LOG_FILE"
  if [ -f "$BACKUP_NAV" ]; then
    cp "$BACKUP_NAV" "$NAV_FILE"
    echo "   - Restored $NAV_FILE from $BACKUP_NAV" | tee -a "$LOG_FILE"
  fi
  exit 1
}
trap 'on_error' ERR

echo "==> Patching admin flag in navigation.blade.php" | tee -a "$LOG_FILE"

# Replace any @php ... @endphp block at top with is_admin-based logic
perl -0777 -pi -e '
  s/@php\s*.*?@endphp/@php
        $user = auth()->user();
        $isAdmin = $user && $user->is_admin;
    @endphp/s
' "$NAV_FILE"

echo "==> Clearing & caching Blade views via docker compose (service: app)" | tee -a "$LOG_FILE"
if command -v docker >/dev/null 2>&1; then
  if docker compose ps app >/dev/null 2>&1; then
    docker compose exec -T app php artisan view:clear   | tee -a "$LOG_FILE"
    docker compose exec -T app php artisan view:cache   | tee -a "$LOG_FILE"
  else
    echo "WARN: docker compose service 'app' not found or not running; skip artisan view cache." | tee -a "$LOG_FILE"
  fi
else
  echo "WARN: docker not found; skipping artisan cache commands." | tee -a "$LOG_FILE"
fi

echo "==> fix_nav_admin_flag_v1.sh completed successfully." | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
