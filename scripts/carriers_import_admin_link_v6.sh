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
      echo "   - WARN: No backup found for $f (expected $backup_path)" | tee -a "$LOG_FILE"
    fi
  done

  echo "WARN: Rollback complete. See $LOG_FILE for details." | tee -a "$LOG_FILE"
}

trap 'echo "ERROR: ${SCRIPT_NAME} failed at line $LINENO" | tee -a "$LOG_FILE"; rollback; exit 1' ERR

# -------------------------------------------------------------------
# Detect how to run artisan
# -------------------------------------------------------------------
ARTISAN="php artisan"

if command -v docker >/dev/null 2>&1; then
  if docker compose ps >/dev/null 2>&1; then
    if docker compose ps app >/dev/null 2>&1; then
      ARTISAN="docker compose exec -T app php artisan"
      echo "==> Using artisan via docker compose (service: app)" | tee -a "$LOG_FILE"
    fi
  fi
fi

# -------------------------------------------------------------------
# 1) Fix navigation: put Carriers Import in right dropdown (admin-only)
# -------------------------------------------------------------------
NAV_FILE="$ROOT_DIR/resources/views/layouts/navigation.blade.php"

if [ -f "$NAV_FILE" ]; then
  backup_file "$NAV_FILE"

  # 1a) Remove stray Carriers Import block that was appended after </nav>, if present
  perl -0pi -e '
    s|\n\{\{\-\- Auto-added: Carriers Import link in Settings menu \-\-\}\}\n<x-dropdown-link href="\{\{ url\(\'/carriers/import\'\) \}\}">\n\s*Carriers Import\n</x-dropdown-link>\n?||s
  ' "$NAV_FILE"

  # 1b) Inject Carriers Import into the dropdown content, above <!-- Authentication -->
  if grep -q "Carriers Import" "$NAV_FILE"; then
    echo "==> Carriers Import already present somewhere in navigation; skipping dropdown injection." | tee -a "$LOG_FILE"
  else
    echo "==> Injecting Carriers Import into right dropdown menu (admin-only)" | tee -a "$LOG_FILE"
    perl -0pi -e '
      s|<!-- Authentication -->|@if(Auth::user() && Auth::user()->usertype === '\''admin'\'')
                        <div class="border-t border-gray-200 my-2"></div>
                        <div class="block px-4 py-2 text-xs text-gray-400">
                            {{ __("Admin Tools") }}
                        </div>
                        <x-dropdown-link href="{{ url('\''/carriers/import'\'') }}">
                            {{ __("Carriers Import") }}
                        </x-dropdown-link>
                    @endif

                    <!-- Authentication -->|s
    ' "$NAV_FILE"
  fi
else
  echo "==> WARN: Navigation file $NAV_FILE not found; nav not patched." | tee -a "$LOG_FILE"
fi

# -------------------------------------------------------------------
# 2) Add Blade guard to Carriers Import view (403 for non-admin)
# -------------------------------------------------------------------
echo "==> Locating Carriers Import view for admin guard..." | tee -a "$LOG_FILE"

CARRIER_VIEW="$ROOT_DIR/resources/views/carriers/import.blade.php"
if [ ! -f "$CARRIER_VIEW" ]; then
  CARRIER_VIEW="$(grep -RIl 'carriers.import' "$ROOT_DIR/resources/views" 2>/dev/null | head -n1 || true)"
fi

if [ -n "$CARRIER_VIEW" ] && [ -f "$CARRIER_VIEW" ]; then
  echo "   - Found Carriers Import view: $CARRIER_VIEW" | tee -a "$LOG_FILE"
  backup_file "$CARRIER_VIEW"

  if grep -q "abort_if(!auth()->check() || auth()->user()->usertype !== 'admin'" "$CARRIER_VIEW"; then
    echo "   - Admin guard already present in Carriers Import view; skipping guard injection." | tee -a "$LOG_FILE"
  else
    if grep -q "<x-app-layout>" "$CARRIER_VIEW"; then
      perl -0pi -e '
        s|<x-app-layout>|@php abort_if(!auth()->check() || auth()->user()->usertype !== '\''admin'\'', 403); @endphp

<x-app-layout>|' "$CARRIER_VIEW"
      echo "   - Inserted admin abort_if guard before <x-app-layout>." | tee -a "$LOG_FILE"
    else
      perl -0pi -e '
        s|^|@php abort_if(!auth()->check() || auth()->user()->usertype !== '\''admin'\'', 403); @endphp

| ' "$CARRIER_VIEW"
      echo "   - Prepended admin abort_if guard at top of view." | tee -a "$LOG_FILE"
    fi
  fi
else
  echo "==> WARN: Could not locate Carriers Import view; no Blade guard applied." | tee -a "$LOG_FILE"
fi

# -------------------------------------------------------------------
# 3) Clear & cache views (best-effort)
# -------------------------------------------------------------------
echo "==> Clearing & caching views (best-effort)" | tee -a "$LOG_FILE"
set +e
$ARTISAN view:clear >>"$LOG_FILE" 2>&1
$ARTISAN view:cache >>"$LOG_FILE" 2>&1
set -e

echo "==> Script ${SCRIPT_NAME} completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
