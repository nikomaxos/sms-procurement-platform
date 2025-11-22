#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/mccmnc_trim_zero_v1_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/mccmnc_trim_zero_v1_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR"      | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE"     | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

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
  fi
}

rollback() {
  echo "==> ERROR: Rolling back changes..." | tee -a "$LOG_FILE"

  for f in "${MOD_FILES[@]}"; do
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    if [ -f "$backup_path" ]; then
      cp "$backup_path" "$f"
      echo "   - Restored $f from $backup_path" | tee -a "$LOG_FILE"
    fi
  done

  echo "==> Rollback complete. See $LOG_FILE for details." | tee -a "$LOG_FILE"
  exit 1
}

trap 'rollback' ERR

NORMALIZER="$ROOT_DIR/app/Support/MccMncNormalizer.php"
NETWORK_MNC="$ROOT_DIR/app/Models/NetworkMnc.php"

if [ ! -f "$NORMALIZER" ]; then
  echo "==> app/Support/MccMncNormalizer.php not found, will create it." | tee -a "$LOG_FILE"
else
  backup_file "$NORMALIZER"
fi

if [ ! -f "$NETWORK_MNC" ]; then
  echo "ERROR: NetworkMnc model not found at $NETWORK_MNC" | tee -a "$LOG_FILE"
  exit 1
fi

backup_file "$NETWORK_MNC"

echo "==> Writing App\\Support\\MccMncNormalizer (5-digit/6-digit rule)" | tee -a "$LOG_FILE"

cat > "$NORMALIZER" <<'PHP'
<?php

namespace App\Support;

/**
 * Normalize MCC/MNC composite codes.
 *
 * Rules:
 * - Strip all non-digits.
 * - If we have 6 digits and the 4th digit is '0', drop that '0' => 5-digit code.
 *   Example: 202001 => 20201 (MCC 202, MNC 001 -> MCC 202, MNC 01).
 * - Otherwise:
 *   - For length <= 6: return the digits as-is.
 *   - For longer strings: consider only the first 6 digits and apply the same rule.
 */
class MccMncNormalizer
{
    public static function normalize(?string $value): string
    {
        $digits = preg_replace('/\D/', '', (string) $value);

        if ($digits === '') {
            return '';
        }

        $len = strlen($digits);

        // Focus on up to 6 digits, as MCC(3) + MNC(2-3)
        if ($len > 6) {
            $digits = substr($digits, 0, 6);
            $len = 6;
        }

        // If 6 digits and the 4th digit (index 3) is '0',
        // drop that '0' so result is 5 digits: MCC + last 2 digits of MNC.
        if ($len === 6 && $digits[3] === '0') {
            return substr($digits, 0, 3) . substr($digits, 4); // 3 + 2 = 5 digits
        }

        // For 5 digits (3+2) or 6 digits (3+3) without the special 0 rule, keep as-is.
        return $digits;
    }
}
PHP

echo "==> Rewriting App\\Models\\NetworkMnc to always use MccMncNormalizer on save" | tee -a "$LOG_FILE"

cat > "$NETWORK_MNC" <<'PHP'
<?php

namespace App\Models;

use App\Support\MccMncNormalizer;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMnc extends Model
{
    protected $table = 'network_mncs';

    protected $fillable = [
        'network_id',
        'mcc',
        'mnc',
        'mcc_mnc',
        'marked_for_deletion',
        'created_by_user_id',
        'updated_by_user_id',
        'created_by_source',
        'updated_by_source',
    ];

    protected $casts = [
        'marked_for_deletion' => 'bool',
    ];

    /**
     * Always recompute mcc_mnc on save using MccMncNormalizer.
     * This covers:
     * - Manual add/edit in the Networks UI.
     * - Any import job that persists NetworkMnc rows.
     */
    protected static function booted(): void
    {
        static::saving(function (NetworkMnc $model): void {
            if ($model->mcc === null || $model->mnc === null) {
                return;
            }

            $mcc = str_pad((string) $model->mcc, 3, '0', STR_PAD_LEFT);
            $mnc = str_pad((string) $model->mnc, 3, '0', STR_PAD_LEFT);

            $raw = $mcc . $mnc;

            if (class_exists(MccMncNormalizer::class)) {
                $model->mcc_mnc = MccMncNormalizer::normalize($raw);
            } else {
                $model->mcc_mnc = $raw;
            }
        });
    }

    public function network(): BelongsTo
    {
        return $this->belongsTo(Network::class);
    }

    /**
     * Simple accessor for MCC+MNC as a 6-digit string (for display).
     * Note: This uses the separate mcc/mnc columns, not the normalized mcc_mnc.
     */
    public function getMccMncFormattedAttribute(): string
    {
        $mcc = str_pad((string) $this->mcc, 3, '0', STR_PAD_LEFT);
        $mnc = str_pad((string) $this->mnc, 3, '0', STR_PAD_LEFT);

        return $mcc . $mnc;
    }
}
PHP

echo "==> Files updated." | tee -a "$LOG_FILE"

echo "==> Clearing & rebuilding caches (best-effort)..." | tee -a "$LOG_FILE"

if command -v docker >/dev/null 2>&1 && docker compose ps >/dev/null 2>&1; then
  SERVICE=""
  if docker compose ps --services 2>/dev/null | grep -qx "app"; then
    SERVICE="app"
  elif docker compose ps --services 2>/dev/null | grep -qx "sms-platform-app"; then
    SERVICE="sms-platform-app"
  fi

  if [ -n "$SERVICE" ]; then
    echo "   - Using docker compose exec $SERVICE" | tee -a "$LOG_FILE"
    docker compose exec -T "$SERVICE" php artisan optimize:clear | tee -a "$LOG_FILE" || true
    docker compose exec -T "$SERVICE" php artisan view:cache       | tee -a "$LOG_FILE" || true
  else
    echo "   - No matching artisan service found; skipping docker artisan commands." | tee -a "$LOG_FILE"
  fi
else
  echo "   - docker compose not available; skipping artisan commands." | tee -a "$LOG_FILE"
fi

trap - ERR

echo "==> mccmnc_trim_zero_v1.sh completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE"                | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
