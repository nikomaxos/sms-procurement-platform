#!/usr/bin/env bash
set -euo pipefail

echo "Running remove_charge_model_field.sh..."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F-%H%M%S)"
BACKUP_DIR=".backups/remove_charge_model_field_${STAMP}"
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
# 1) Remove "Charge Model" form group from CREATE view
#    Match any <div> whose label text is exactly "Charge Model"
# -----------------------------------------------------------
if [ -f "$CREATE" ]; then
  echo "  - Removing Charge Model block from $CREATE"
  perl -0pi -e 's#\s*<div[^>]*>\s*<label[^>]*>\s*Charge Model\s*<\/label>.*?<\/div>##sg' "$CREATE"

  # In case there was a guard block for $chargeModels, make sure it's optional:
  perl -0pi -e 's/\$chargeModels\s*=\s*\$chargeModels\s*\?\?\s*collect\(\);/\$chargeModels = \$chargeModels ?? collect();/g' "$CREATE" || true
fi

# -----------------------------------------------------------
# 2) Remove "Charge Model" filter / mass-update fields
#    from INDEX view (same pattern: label text = Charge Model)
# -----------------------------------------------------------
if [ -f "$INDEX" ]; then
  echo "  - Removing Charge Model filter/mass-update blocks from $INDEX"

  # Remove any <div> containing a label "Charge Model"
  perl -0pi -e 's#\s*<div[^>]*>\s*<label[^>]*>\s*Charge Model\s*<\/label>.*?<\/div>##sg' "$INDEX"

  # Remove table header column "Charge Model"
  perl -0pi -e 's#<th[^>]*>\s*Charge Model\s*<\/th>##sg' "$INDEX"

  # Remove table cells that reference charge_model in the offers list
  perl -0pi -e 's#<td[^>]*>.*?charge_model.*?<\/td>##sg' "$INDEX"

  # Optional: if a guard block for $chargeModels exists, keep it harmless
  perl -0pi -e 's/\$chargeModels\s*=\s*\$chargeModels\s*\?\?\s*collect\(\);/\$chargeModels = \$chargeModels ?? collect();/g' "$INDEX" || true
fi

# -----------------------------------------------------------
# 3) Clean up any JS "hide Charge Model" helper we added earlier
# -----------------------------------------------------------
for f in "$INDEX" "$CREATE"; do
  if [ -f "$f" ]; then
    perl -0pi -e 's/\{\-\- Auto-hide legacy Charge Model field.*?END hide Charge Model label \-\-\}\n?//sg' "$f" || true
  fi
done

echo "Checking remaining references to Charge Model in views..."
grep -RIn "Charge Model" resources/views/offers || echo "  - No remaining 'Charge Model' labels in offers views."

echo "Clearing compiled views..."

# Prefer docker compose artisan if available; fall back to local php artisan
if command -v docker >/dev/null 2>&1 && docker compose ps app >/dev/null 2>&1; then
  docker compose exec -T app php artisan view:clear || true
else
  php artisan view:clear || true
fi

echo "Done. Charge Model field is removed from Offers UI."
