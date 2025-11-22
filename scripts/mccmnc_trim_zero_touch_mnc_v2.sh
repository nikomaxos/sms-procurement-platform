#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/mccmnc_trim_zero_touch_mnc_v2_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/mccmnc_trim_zero_touch_mnc_v2_${TS}.log"

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

NETWORK_MNC="$ROOT_DIR/app/Models/NetworkMnc.php"

if [ ! -f "$NETWORK_MNC" ]; then
  echo "ERROR: NetworkMnc model not found at $NETWORK_MNC" | tee -a "$LOG_FILE"
  exit 1
fi

backup_file "$NETWORK_MNC"

echo "==> Rewriting App\\Models\\NetworkMnc so mnc is trimmed according to normalized MCCMNC" | tee -a "$LOG_FILE"

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
     * Always recompute mcc, mnc, and mcc_mnc on save using MccMncNormalizer.
     *
     * This covers:
     * - Manual add/edit in the Networks UI.
     * - Any import job that persists NetworkMnc rows.
     *
     * Rule:
     *  - Build a 6-digit raw MCCMNC from MCC(3) + MNC(3).
     *  - Normalize via MccMncNormalizer (which trims the 4th digit 0 => 5-digit code).
     *  - Re-split normalized value into MCC (first 3) and MNC (last 2 or 3).
     *  - Persist all three: mcc, mnc, mcc_mnc.
     */
    protected static function booted(): void
    {
        static::saving(function (NetworkMnc $model): void {
            if ($model->mcc === null || $model->mnc === null) {
                return;
            }

            // Sanitise into digits
            $mccDigits = preg_replace('/\D/', '', (string) $model->mcc);
            $mncDigits = preg_replace('/\D/', '', (string) $model->mnc);

            if ($mccDigits === '' || $mncDigits === '') {
                return;
            }

            // Build raw 6-digit MCCMNC from padded parts (3+3)
            $raw = str_pad($mccDigits, 3, '0', STR_PAD_LEFT)
                 . str_pad($mncDigits, 3, '0', STR_PAD_LEFT);

            $normalized = $raw;

            if (class_exists(MccMncNormalizer::class)) {
                $normalized = MccMncNormalizer::normalize($raw);
            } else {
                $normalized = preg_replace('/\D/', '', $raw);
            }

            $normalized = (string) $normalized;
            $len = strlen($normalized);

            if ($len < 5) {
                // Fallback: keep original ints, but at least store something in mcc_mnc
                $model->mcc_mnc = $normalized !== '' ? $normalized : $raw;
                return;
            }

            // MCC is always the first 3 digits
            $mccNorm = substr($normalized, 0, 3);

            // For 5-digit: MCC(3) + MNC(2)
            // For 6-digit: MCC(3) + MNC(3)
            if ($len === 5) {
                $mncNorm = substr($normalized, 3, 2);
            } else {
                $mncNorm = substr($normalized, 3); // remaining digits (usually 3)
            }

            $model->mcc = (int) $mccNorm;
            $model->mnc = (int) $mncNorm;
            $model->mcc_mnc = $normalized;
        });
    }

    public function network(): BelongsTo
    {
        return $this->belongsTo(Network::class);
    }

    /**
     * Accessor for formatted MCCMNC.
     *
     * Prefer the normalized mcc_mnc column if present; otherwise rebuild from mcc/mnc.
     */
    public function getMccMncFormattedAttribute(): string
    {
        if (!empty($this->mcc_mnc)) {
            return (string) $this->mcc_mnc;
        }

        $mcc = str_pad((string) $this->mcc, 3, '0', STR_PAD_LEFT);

        $mncStr = (string) $this->mnc;
        if ($mncStr === '') {
            return $mcc;
        }

        // If 1–2 digits, show as 2-digit; if 3+, show as-is
        $len = strlen($mncStr);
        if ($len <= 2) {
            $mnc = str_pad($mncStr, 2, '0', STR_PAD_LEFT);
        } else {
            $mnc = $mncStr;
        }

        return $mcc . $mnc;
    }
}
PHP

echo "==> NetworkMnc updated." | tee -a "$LOG_FILE"

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

echo "==> mccmnc_trim_zero_touch_mnc_v2.sh completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE"                | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
