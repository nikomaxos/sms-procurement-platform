#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/fix_carriers_import_is_admin_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/fix_carriers_import_is_admin_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR" | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE" | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

# -------------------------------------------------------------------
# Helpers: backup + rollback
# -------------------------------------------------------------------
declare -a MOD_FILES=()

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    mkdir -p "$(dirname "$backup_path")" 2>/dev/null || true
    cp "$f" "$backup_path"
    MOD_FILES+=("$f")
    echo "==> Backed up $f -> $backup_path" | tee -a "$LOG_FILE"
  else
    echo "==> WARN: Tried to back up missing file $f" | tee -a "$LOG_FILE"
  fi
}

rollback() {
  echo "==> Rolling back modified files..." | tee -a "$LOG_FILE"

  for f in "${MOD_FILES[@]}"; do
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    if [ -f "$backup_path" ]; then
      cp "$backup_path" "$f"
      echo "   - Restored $f from $backup_path" | tee -a "$LOG_FILE"
    else
      echo "   - No backup found for $f (skipped)" | tee -a "$LOG_FILE"
    fi
  done

  echo "WARN: Rollback complete. See $LOG_FILE for details." | tee -a "$LOG_FILE"
}

on_error() {
  local lineno="$1"
  echo "ERROR: ${SCRIPT_NAME} failed at line ${lineno}" | tee -a "$LOG_FILE"
  rollback
  exit 1
}

trap 'on_error $LINENO' ERR

# -------------------------------------------------------------------
# Decide how to call artisan (inside container if available)
# -------------------------------------------------------------------
if docker compose ps app >/dev/null 2>&1; then
  ARTISAN="docker compose exec -T app php artisan"
  echo "==> Using artisan via docker compose (service: app)" | tee -a "$LOG_FILE"
else
  ARTISAN="php artisan"
  echo "==> Using artisan directly on host" | tee -a "$LOG_FILE"
fi

# -------------------------------------------------------------------
# 1) Fix navigation conditions: usertype -> is_admin
# -------------------------------------------------------------------
NAV_FILE="$ROOT_DIR/resources/views/layouts/navigation.blade.php"

if [ -f "$NAV_FILE" ]; then
  echo "==> Patching navigation file: $NAV_FILE" | tee -a "$LOG_FILE"
  backup_file "$NAV_FILE"

  # Replace any checks that still use usertype === 'admin'
  perl -0pi -e "s/auth\\(\\)->user\\(\\)->usertype === 'admin'/auth()->user()->is_admin/g" "$NAV_FILE"

  echo "   - navigation.blade.php now checks auth()->user()->is_admin" | tee -a "$LOG_FILE"
else
  echo "==> WARN: navigation file $NAV_FILE not found; skipping nav patch." | tee -a "$LOG_FILE"
fi

# -------------------------------------------------------------------
# 2) Fix carriers/import view guard: usertype -> is_admin
# -------------------------------------------------------------------
CARRIERS_VIEW="$ROOT_DIR/resources/views/carriers/import.blade.php"

if [ -f "$CARRIERS_VIEW" ]; then
  echo "==> Patching carriers import view: $CARRIERS_VIEW" | tee -a "$LOG_FILE"
  backup_file "$CARRIERS_VIEW"

  # Guard we previously inserted:
  # if (! auth()->check() || auth()->user()->usertype !== 'admin') { abort(403); }
  # -> if (! auth()->check() || ! auth()->user()->is_admin) { abort(403); }
  perl -0pi -e "s/! auth\\(\\)->check\\(\\) \\|\\| auth\\(\\)->user\\(\\)->usertype !== 'admin'/! auth()->check() || ! auth()->user()->is_admin/g" "$CARRIERS_VIEW"

  # Any remaining direct equality checks
  perl -0pi -e "s/auth\\(\\)->user\\(\\)->usertype === 'admin'/auth()->user()->is_admin/g" "$CARRIERS_VIEW"

  echo "   - carriers/import view now also uses is_admin." | tee -a "$LOG_FILE"
else
  echo "==> WARN: carriers/import.blade.php not found; skipping view patch." | tee -a "$LOG_FILE"
fi

# -------------------------------------------------------------------
# 3) Clear & rebuild caches (best-effort)
# -------------------------------------------------------------------
echo "==> Clearing & rebuilding caches (optimize:clear, view:cache)" | tee -a "$LOG_FILE"

set +e
$ARTISAN optimize:clear >>"$LOG_FILE" 2>&1
$ARTISAN view:cache     >>"$LOG_FILE" 2>&1
set -e

echo "==> fix_carriers_import_is_admin_v1.sh completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
