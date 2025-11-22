#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/network_mncs_db_normalizer_v1_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/network_mncs_db_normalizer_v1_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR"      | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE"     | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

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
  fi
}

register_new_file() {
  local f="$1"
  NEW_FILES+=("$f")
  echo "==> Will treat $f as NEW (remove on rollback)" | tee -a "$LOG_FILE"
}

rollback() {
  echo "==> ERROR: Rolling back changes..." | tee -a "$LOG_FILE"

  # Restore modified files
  for f in "${MOD_FILES[@]}"; do
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    if [ -f "$backup_path" ]; then
      cp "$backup_path" "$f"
      echo "   - Restored $f from $backup_path" | tee -a "$LOG_FILE"
    fi
  done

  # Remove new files
  for f in "${NEW_FILES[@]}"; do
    if [ -f "$f" ]; then
      rm -f "$f"
      echo "   - Removed new file $f" | tee -a "$LOG_FILE"
    fi
  done

  echo "==> Rollback complete. See $LOG_FILE for details." | tee -a "$LOG_FILE"
  exit 1
}

trap 'rollback' ERR

MIG_DIR="$ROOT_DIR/database/migrations"
existing_mig="$(ls "$MIG_DIR"/*_add_network_mncs_normalizer_trigger.php 2>/dev/null | head -n 1 || true)"

if [ -n "$existing_mig" ]; then
  MIG_FILE="$existing_mig"
  echo "==> Reusing existing migration file: $MIG_FILE" | tee -a "$LOG_FILE"
  backup_file "$MIG_FILE"
else
  MIG_TS="$(date +%Y_%m_%d_%H%M%S)"
  MIG_FILE="$MIG_DIR/${MIG_TS}_add_network_mncs_normalizer_trigger.php"
  echo "==> Creating new migration file: $MIG_FILE" | tee -a "$LOG_FILE"
  register_new_file "$MIG_FILE"
fi

cat > "$MIG_FILE" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Create or replace function that normalizes MCC/MNC:
        // - Build raw MCCMNC from padded MCC(3) + MNC(3)
        // - If 6 digits and 4th digit is '0', drop that '0' => 5-digit code
        // - Recompute MCC (first 3) and MNC (last 2 or 3) from normalized value
        DB::unprepared(<<<'SQL'
CREATE OR REPLACE FUNCTION normalize_network_mncs()
RETURNS trigger AS $$
DECLARE
    v_mcc   text;
    v_mnc   text;
    v_raw   text;
    v_norm  text;
    v_len   int;
BEGIN
    IF NEW.mcc IS NULL OR NEW.mnc IS NULL THEN
        RETURN NEW;
    END IF;

    -- Strip to digits
    v_mcc := regexp_replace(COALESCE(NEW.mcc::text, ''), '\D', '', 'g');
    v_mnc := regexp_replace(COALESCE(NEW.mnc::text, ''), '\D', '', 'g');

    IF v_mcc = '' OR v_mnc = '' THEN
        RETURN NEW;
    END IF;

    -- Build raw MCCMNC as 6 digits: MCC(3) + MNC(3)
    v_raw := lpad(v_mcc, 3, '0') || lpad(v_mnc, 3, '0');

    -- Keep only digits, max 6 chars
    v_norm := regexp_replace(v_raw, '\D', '', 'g');
    v_len  := length(v_norm);

    IF v_len > 6 THEN
        v_norm := substring(v_norm from 1 for 6);
        v_len  := 6;
    END IF;

    -- If 6 digits and 4th digit is '0', drop that '0' => 5-digit composite
    IF v_len = 6 AND substring(v_norm from 4 for 1) = '0' THEN
        v_norm := substring(v_norm from 1 for 3) || substring(v_norm from 5);
        v_len  := 5;
    END IF;

    -- If we ended up with fewer than 5 digits, just store what we have in mcc_mnc
    IF v_len < 5 THEN
        NEW.mcc_mnc := v_norm;
        RETURN NEW;
    END IF;

    -- MCC is always first 3
    NEW.mcc := substring(v_norm from 1 for 3)::integer;

    -- For 5-digit: MCC(3) + MNC(2)
    -- For 6-digit: MCC(3) + MNC(3)
    IF v_len = 5 THEN
        NEW.mnc := substring(v_norm from 4 for 2)::integer;
    ELSE
        NEW.mnc := substring(v_norm from 4)::integer;
    END IF;

    NEW.mcc_mnc := v_norm;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_network_mncs_normalize ON network_mncs;

CREATE TRIGGER trg_network_mncs_normalize
BEFORE INSERT OR UPDATE ON network_mncs
FOR EACH ROW EXECUTE FUNCTION normalize_network_mncs();
SQL
        );

        // Retro-normalize all existing rows by forcing an UPDATE
        DB::unprepared("UPDATE network_mncs SET mcc = mcc WHERE mcc IS NOT NULL AND mnc IS NOT NULL;");
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
DROP TRIGGER IF EXISTS trg_network_mncs_normalize ON network_mncs;
DROP FUNCTION IF EXISTS normalize_network_mncs();
SQL
        );
    }
};
PHP

echo "==> Migration file written: $MIG_FILE" | tee -a "$LOG_FILE"

# Run migrations inside container if possible
echo "==> Running php artisan migrate --force" | tee -a "$LOG_FILE"

ARTISAN_CMD="php artisan migrate --force"

if command -v docker >/dev/null 2>&1 && docker compose ps >/dev/null 2>&1; then
  SERVICE=""
  if docker compose ps --services 2>/dev/null | grep -qx "app"; then
    SERVICE="app"
  elif docker compose ps --services 2>/dev/null | grep -qx "sms-platform-app"; then
    SERVICE="sms-platform-app"
  fi

  if [ -n "$SERVICE" ]; then
    echo "   - Using docker compose exec $SERVICE" | tee -a "$LOG_FILE"
    docker compose exec -T "$SERVICE" $ARTISAN_CMD | tee -a "$LOG_FILE"
  else
    echo "   - No matching artisan service found; attempting local migrate" | tee -a "$LOG_FILE"
    (cd "$ROOT_DIR" && $ARTISAN_CMD) | tee -a "$LOG_FILE"
  fi
else
  echo "   - docker compose not available; attempting local migrate" | tee -a "$LOG_FILE"
  (cd "$ROOT_DIR" && $ARTISAN_CMD) | tee -a "$LOG_FILE"
fi

echo "==> Clearing & rebuilding caches (best-effort)..." | tee -a "$LOG_FILE"

if command -v docker >/dev/null 2>&1 && docker compose ps >/dev/null 2>&1; then
  SERVICE=""
  if docker compose ps --services 2>/dev/null | grep -qx "app"; then
    SERVICE="app"
  elif docker compose ps --services 2>/dev/null | grep -qx "sms-platform-app"; then
    SERVICE="sms-platform-app"
  fi

  if [ -n "$SERVICE" ]; then
    echo "   - Using docker compose exec $SERVICE for optimize:clear & view:cache" | tee -a "$LOG_FILE"
    docker compose exec -T "$SERVICE" php artisan optimize:clear | tee -a "$LOG_FILE" || true
    docker compose exec -T "$SERVICE" php artisan view:cache       | tee -a "$LOG_FILE" || true
  else
    echo "   - No matching service found; skipping docker artisan cache commands." | tee -a "$LOG_FILE"
  fi
else
  echo "   - docker compose not available; skipping artisan cache commands." | tee -a "$LOG_FILE"
fi

trap - ERR

echo "==> network_mncs_db_normalizer_v1.sh completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE"                | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
