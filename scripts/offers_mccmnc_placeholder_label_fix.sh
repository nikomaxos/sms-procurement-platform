#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_mccmnc_placeholder_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/resources/views/offers"

# Backups
if [ -f "resources/views/offers/create.blade.php" ]; then
  cp resources/views/offers/create.blade.php "${BACKUP_DIR}/resources/views/offers/" \
    || echo "WARN: could not backup create.blade.php"
fi

if [ -f "resources/views/offers/edit.blade.php" ]; then
  cp resources/views/offers/edit.blade.php "${BACKUP_DIR}/resources/views/offers/" \
    || echo "WARN: could not backup edit.blade.php"
fi

# Διόρθωση placeholder/κειμένου dropdown από "Select MNC" σε "Select MCCMNC"
for f in resources/views/offers/create.blade.php resources/views/offers/edit.blade.php; do
  if [ -f "$f" ]; then
    # πιο συγκεκριμένα patterns για να ΜΗν πειράξουμε τα ονόματα των πεδίων (network_mnc_id κτλ.)
    perl -pi -e 's/Select MNC/Select MCCMNC/g' "$f"
    perl -pi -e 's/select MNC/select MCCMNC/g' "$f"
    perl -pi -e 's/select mnc/select MCCMNC/g' "$f"
  fi
done

echo "==> Done. Placeholder text for MNC dropdowns updated to MCCMNC. Backup at: ${BACKUP_DIR}"
