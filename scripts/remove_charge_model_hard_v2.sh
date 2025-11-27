#!/usr/bin/env bash
set -euo pipefail

echo "Running remove_charge_model_hard_v2.sh..."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F-%H%M%S)"
BACKUP_DIR=".backups/remove_charge_model_hard_v2_${STAMP}"
echo "Backup dir: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

INDEX="resources/views/offers/index.blade.php"
CREATE="resources/views/offers/create.blade.php"

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  - Backing up $f"
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    cp "$f" "$BACKUP_DIR/$f"
  else
    echo "  - WARNING: $f not found, skipping backup"
  fi
}

backup_file "$INDEX"
backup_file "$CREATE"

# -----------------------------------------------------------
# 1) CREATE VIEW: remove Charge Model field and any ChargeModel
# -----------------------------------------------------------
if [ -f "$CREATE" ]; then
  echo "  - Stripping Charge Model block and ChargeModel code from $CREATE"

  # Remove any <div> whose label text contains "Charge Model" (case-insensitive)
  perl -0pi -e 's#\s*<div[^>]*>\s*<label[^>]*>[^<]*Charge Model[^<]*</label>.*?</div>##gsi' "$CREATE"

  # Remove lines with the ChargeModel model or $chargeModels guard/scraps
  perl -pi -e 's/^.*ChargeModel::orderBy.*$//g' "$CREATE"
  perl -pi -e 's/^.*\$chargeModels.*$//g'        "$CREATE"

  # Also remove any stray literal label text "Charge Model"
  perl -pi -e 's/Charge Model//g' "$CREATE"
fi

# -----------------------------------------------------------
# 2) INDEX VIEW: remove Charge Model from filters/table + scraps
# -----------------------------------------------------------
if [ -f "$INDEX" ]; then
  echo "  - Stripping Charge Model filter, column and ChargeModel code from $INDEX"

  # Remove any <div> with label containing "Charge Model" (filters / mass update)
  perl -0pi -e 's#\s*<div[^>]*>\s*<label[^>]*>[^<]*Charge Model[^<]*</label>.*?</div>##gsi' "$INDEX"

  # Remove table header "Charge Model"
  perl -0pi -e 's#<th[^>]*>\s*Charge Model\s*</th>##gsi' "$INDEX"

  # Remove any <td> that references charge_model in the row
  perl -0pi -e 's#<td[^>]*>[^<]*charge_model[^<]*</td>##gsi' "$INDEX"

  # Remove lines with the ChargeModel model or $chargeModels
  perl -pi -e 's/^.*ChargeModel::orderBy.*$//g' "$INDEX"
  perl -pi -e 's/^.*\$chargeModels.*$//g'       "$INDEX"

  # Remove any stray literal label text "Charge Model"
  perl -pi -e 's/Charge Model//g' "$INDEX"
fi

echo "  - Checking remaining references to Charge Model / ChargeModel in offers views..."
grep -RIn "Charge Model" resources/views/offers || echo "    No remaining 'Charge Model' text."
grep -RIn "ChargeModel"   resources/views/offers || echo "    No remaining 'ChargeModel' usages."
grep -RIn "chargeModels"  resources/views/offers || echo "    No remaining '\$chargeModels' usages."

echo "Clearing compiled Blade views..."
if command -v docker >/dev/null 2>&1 && docker compose ps app >/dev/null 2>&1; then
  docker compose exec -T app php artisan view:clear || true
  docker compose exec -T app php artisan optimize:clear || true
else
  php artisan view:clear || true
  php artisan optimize:clear || true
fi

echo "Done. Charge Model removed from Offers UI and scrap line cleaned."
