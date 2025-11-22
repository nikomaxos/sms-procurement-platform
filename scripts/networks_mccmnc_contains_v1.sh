#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/networks_mccmnc_contains_v1_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/networks_mccmnc_contains_v1_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR"      | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE"     | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

NET_INDEX="$ROOT_DIR/resources/views/networks/index.blade.php"

if [ ! -f "$NET_INDEX" ]; then
  echo "ERROR: networks index view not found at $NET_INDEX" | tee -a "$LOG_FILE"
  exit 1
fi

# Backup once
REL="${NET_INDEX#"$ROOT_DIR/"}"
BACKUP_PATH="${BACKUP_DIR}/${REL//\//_}"
mkdir -p "$(dirname "$BACKUP_PATH")" 2>/dev/null || true
cp "$NET_INDEX" "$BACKUP_PATH"
echo "==> Backed up $NET_INDEX -> $BACKUP_PATH" | tee -a "$LOG_FILE"

# Patch: exact match -> contains (LIKE %digits%)
echo "==> Patching MCCMNC filter condition to use LIKE (contains)" | tee -a "$LOG_FILE"

SEARCH="->where('nm2.mcc_mnc', \$normalized);"
REPLACE="->where('nm2.mcc_mnc', 'LIKE', '%' . \$normalized . '%');"

if grep -Fq "$SEARCH" "$NET_INDEX"; then
  sed -i "s/$SEARCH/$REPLACE/" "$NET_INDEX"
  echo "   - Replaced exact match with LIKE contains logic." | tee -a "$LOG_FILE"
else
  echo "   - Pattern not found (it may already be using LIKE). No changes applied." | tee -a "$LOG_FILE"
fi

# Clear & rebuild Blade caches (best effort)
ARTISAN_SERVICE=""

if command -v docker >/dev/null 2>&1 && docker compose ps >/dev/null 2>&1; then
  if docker compose ps --services 2>/dev/null | grep -qx "app"; then
    ARTISAN_SERVICE="app"
  elif docker compose ps --services 2>/dev/null | grep -qx "sms-platform-app"; then
    ARTISAN_SERVICE="sms-platform-app"
  fi
fi

if [ -n "$ARTISAN_SERVICE" ]; then
  echo "==> Clearing & caching views via docker compose ($ARTISAN_SERVICE)" | tee -a "$LOG_FILE"
  docker compose exec -T "$ARTISAN_SERVICE" php artisan view:clear  | tee -a "$LOG_FILE" || true
  docker compose exec -T "$ARTISAN_SERVICE" php artisan view:cache  | tee -a "$LOG_FILE" || true
else
  echo "==> No artisan service detected; skipping view cache commands." | tee -a "$LOG_FILE"
fi

echo "==> networks_mccmnc_contains_v1.sh completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE"                | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
