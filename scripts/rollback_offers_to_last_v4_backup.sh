#!/usr/bin/env bash

echo "==> Rolling back offers-related files from latest backup_offers_v4_*"

PROJECT_ROOT="$(pwd)"

# Βρες το πιο πρόσφατο backup του τύπου backup_offers_v4_*
LATEST_V4_BACKUP_DIR="$(ls -1d "${PROJECT_ROOT}"/backup_offers_v4_* 2>/dev/null | sort | tail -n1)"

if [ -z "${LATEST_V4_BACKUP_DIR}" ]; then
  echo "!! No backup_offers_v4_* directory found. Nothing to rollback from."
  echo "   Try: ls -1d backup_offers_*  to see what backups you actually have."
  echo "==> Rollback script finished with no changes."
  exit 0
fi

echo "==> Using backup directory: ${LATEST_V4_BACKUP_DIR}"

restore_file() {
  local REL_PATH="$1"
  local SRC="${LATEST_V4_BACKUP_DIR}/${REL_PATH}"
  local DST="${PROJECT_ROOT}/${REL_PATH}"

  if [ -f "${SRC}" ]; then
    mkdir -p "$(dirname "${DST}")" 2>/dev/null || true
    cp "${SRC}" "${DST}" && echo "Restored: ${REL_PATH}"
  else
    echo "Skipping (not found in backup): ${REL_PATH}"
  fi
}

# Αρχεία που είχαν πειραχτεί από τα offers scripts
restore_file "app/Models/SupplierOffer.php"
restore_file "app/Http/Controllers/OffersController.php"
restore_file "resources/views/offers/index.blade.php"
restore_file "resources/views/offers/edit.blade.php"

echo "==> Rollback complete. Application is now back to the state of:"
echo "   ${LATEST_V4_BACKUP_DIR}"
echo "==> Now refresh /offers and /offers/{id}/edit in your browser to verify."
exit 0
