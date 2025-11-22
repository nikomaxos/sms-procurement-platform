#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/carriers_import_admin_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/carriers_import_admin_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR" | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE" | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

# Track modified / new files for rollback
declare -a MOD_FILES=()
declare -a NEW_FILES=()

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

remove_new_files() {
  for f in "${NEW_FILES[@]}"; do
    if [ -f "$f" ]; then
      rm -f "$f"
      echo "   - Removed new file $f" | tee -a "$LOG_FILE"
    fi
  done
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
      echo "   - WARN: Backup not found for $f (expected $backup_path)" | tee -a "$LOG_FILE"
    fi
  done

  if [ "${#NEW_FILES[@]}" -gt 0 ]; then
    echo "==> Removing newly created files..." | tee -a "$LOG_FILE"
    remove_new_files
  fi

  echo "WARN: Rollback complete. See $LOG_FILE for details." | tee -a "$LOG_FILE"
}

trap 'echo "ERROR: ${SCRIPT_NAME} failed at line $LINENO" | tee -a "$LOG_FILE"; rollback; exit 1' ERR

# -------------------------------------------------------------------
# Determine how to call artisan (plain or via docker compose)
# -------------------------------------------------------------------
ARTISAN="php artisan"

if command -v docker >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; then
  # Prefer docker compose v2
  if command -v docker >/dev/null 2>&1 && docker compose ps >/dev/null 2>&1; then
    if docker compose ps app >/dev/null 2>&1; then
      ARTISAN="docker compose exec -T app php artisan"
      echo "==> Using artisan via: $ARTISAN" | tee -a "$LOG_FILE"
    fi
  # Fallback to docker-compose v1
  elif command -v docker-compose >/dev/null 2>&1 && docker-compose ps >/dev/null 2>&1; then
    if docker-compose ps app >/dev/null 2>&1; then
      ARTISAN="docker-compose exec -T app php artisan"
      echo "==> Using artisan via: $ARTISAN" | tee -a "$LOG_FILE"
    fi
  else
    echo "==> Docker compose not usable; falling back to local php artisan" | tee -a "$LOG_FILE"
  fi
else
  echo "==> Docker not found; using local php artisan" | tee -a "$LOG_FILE"
fi

# -------------------------------------------------------------------
# Step 1: Patch navigation to add Carriers Import under Settings area
# (desktop nav), visible only to admins (is_admin)
# -------------------------------------------------------------------
NAV_FILE="$ROOT_DIR/resources/views/layouts/navigation.blade.php"

if [ -f "$NAV_FILE" ]; then
  if grep -q "carriers.import" "$NAV_FILE"; then
    echo "==> Navigation already contains carriers.import link; skipping nav patch." | tee -a "$LOG_FILE"
  else
    echo "==> Patching navigation: $NAV_FILE" | tee -a "$LOG_FILE"
    backup_file "$NAV_FILE"

    # Inject our admin-only Carriers Import button just before the
    # Jetstream "Hamburger" section (desktop area).
    perl -0pi -e "
      s|(<!-- Hamburger -->)|@if(auth()->check() && auth()->user()->is_admin)
    <div class=\"hidden sm:flex sm:items-center sm:ml-6\">
        <a href=\"{{ route('carriers.import') }}\"
           class=\"inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500\">
            Carriers Import
        </a>
    </div>
@endif

\$1|s" "$NAV_FILE"

    echo "   - Carriers Import link injected into navigation (admin-only)" | tee -a "$LOG_FILE"
  fi
else
  echo "==> WARN: Navigation file $NAV_FILE not found; nav patch skipped." | tee -a "$LOG_FILE"
fi

# -------------------------------------------------------------------
# Step 2: Add server-side admin guard to Carriers Import view
# (abort 403 if not auth or not is_admin)
# -------------------------------------------------------------------
echo "==> Locating Carriers Import Blade view..." | tee -a "$LOG_FILE"
CARRIER_VIEW=""

set +e
CARRIER_VIEW="$(grep -RIl 'Carriers Import' \"$ROOT_DIR/resources/views\" 2>/dev/null | head -n1)"
if [ -z "$CARRIER_VIEW" ]; then
  CARRIER_VIEW="$(grep -RIl 'carriers.import' \"$ROOT_DIR/resources/views\" 2>/dev/null | head -n1)"
fi
set -e

if [ -z "$CARRIER_VIEW" ]; then
  echo "==> WARN: Could not locate Carriers Import view; admin guard not injected." | tee -a "$LOG_FILE"
else
  echo "   - Found Carriers Import view at: $CARRIER_VIEW" | tee -a "$LOG_FILE"

  if grep -q "abort_if(!auth()->check() || !auth()->user()->is_admin" "$CARRIER_VIEW"; then
    echo "   - Admin guard already present in view; skipping." | tee -a "$LOG_FILE"
  else
    backup_file "$CARRIER_VIEW"
    echo "   - Injecting admin-only guard into Carriers Import view..." | tee -a "$LOG_FILE"

    if grep -q "<x-app-layout>" "$CARRIER_VIEW"; then
      # Insert guard just before <x-app-layout>
      perl -0pi -e "
        s|<x-app-layout>|@php abort_if(!auth()->check() || !auth()->user()->is_admin, 403); @endphp

<x-app-layout>|" "$CARRIER_VIEW"
    else
      # Fallback: prepend guard at top of file
      perl -0pi -e "
        s|^|@php abort_if(!auth()->check() || !auth()->user()->is_admin, 403); @endphp

|" "$CARRIER_VIEW"
    fi

    echo "   - Admin guard injected." | tee -a "$LOG_FILE"
  fi
fi

# -------------------------------------------------------------------
# Step 3: Clear & rebuild caches (best-effort)
# -------------------------------------------------------------------
echo "==> Clearing & rebuilding caches (optimize:clear, view:cache)" | tee -a "$LOG_FILE"
set +e
$ARTISAN optimize:clear >>"$LOG_FILE" 2>&1
OPT_RC=$?
if [ $OPT_RC -ne 0 ]; then
  echo "   - WARN: artisan optimize:clear failed with code $OPT_RC (continuing)." | tee -a "$LOG_FILE"
fi

$ARTISAN view:cache >>"$LOG_FILE" 2>&1
VIEW_RC=$?
if [ $VIEW_RC -ne 0 ]; then
  echo "   - WARN: artisan view:cache failed with code $VIEW_RC (continuing)." | tee -a "$LOG_FILE"
fi
set -e

echo "==> Script ${SCRIPT_NAME} completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
