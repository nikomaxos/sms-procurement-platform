#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_use_mccmnc_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/resources/views/offers"

# Backups
if [ -f "resources/views/offers/create.blade.php" ]; then
  cp resources/views/offers/create.blade.php "${BACKUP_DIR}/resources/views/offers/" \
    || echo "WARN: could not backup create.blade.php"
else
  echo "!! resources/views/offers/create.blade.php not found. Aborting."
  exit 1
fi

if [ -f "resources/views/offers/edit.blade.php" ]; then
  cp resources/views/offers/edit.blade.php "${BACKUP_DIR}/resources/views/offers/" \
    || echo "WARN: could not backup edit.blade.php"
fi

# Σε create & edit views, όπου γράφαμε ->mnc για το label του dropdown, 
# το γυρνάμε σε ->mcc_mnc
perl -pi -e 's/->mnc\b/->mcc_mnc/g' resources/views/offers/create.blade.php
perl -pi -e 's/->mnc\b/->mcc_mnc/g' resources/views/offers/edit.blade.php

echo "==> Updated create/edit MNC labels to use mcc_mnc. Backup at: ${BACKUP_DIR}"
