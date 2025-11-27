#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_cleanup_auto_select_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/resources/views/offers"

# Backups
for f in resources/views/offers/create.blade.php resources/views/offers/edit.blade.php resources/views/offers/index.blade.php; do
  if [ -f "$f" ]; then
    cp "$f" "${BACKUP_DIR}/resources/views/offers/" || echo "WARN: could not backup $f"
  fi
done

# Σβήσε οποιαδήποτε γραμμή που περιέχει το offers.partials.auto_select_single_mnc
for f in resources/views/offers/create.blade.php resources/views/offers/edit.blade.php resources/views/offers/index.blade.php; do
  if [ -f "$f" ]; then
    perl -ni -e 'print unless /offers\.partials\.auto_select_single_mnc/' "$f"
  fi
done

echo "==> Done. Removed stray text lines with offers.partials.auto_select_single_mnc. Backup at: ${BACKUP_DIR}"
