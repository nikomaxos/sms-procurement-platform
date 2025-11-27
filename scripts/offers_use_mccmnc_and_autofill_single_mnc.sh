#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_use_mccmnc_and_autofill_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/resources/views/offers" "${BACKUP_DIR}/app/Http/Controllers"

########################################
# 1) Backups
########################################

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

if [ -f "app/Http/Controllers/OffersController.php" ]; then
  cp app/Http/Controllers/OffersController.php "${BACKUP_DIR}/app/Http/Controllers/" \
    || echo "WARN: could not backup OffersController.php"
fi

########################################
# 2) Στα create/edit views: όπου το label του dropdown MNC
#    χρησιμοποιεί ->mnc, το γυρνάμε σε ->mcc_mnc
########################################

# Αυτό είναι idempotent: αν δεν υπάρχει πια ->mnc, δεν κάνει ζημιά.
perl -pi -e 's/->mnc\b/->mcc_mnc/g' resources/views/offers/create.blade.php || true
perl -pi -e 's/->mnc\b/->mcc_mnc/g' resources/views/offers/edit.blade.php   || true

########################################
# 3) Στο OffersController@store:
#    Αν ΔΕΝ έχει έρθει network_mnc_id αλλά έχει network_id,
#    και το network έχει ΑΚΡΙΒΩΣ ένα MNC, το συμπληρώνουμε αυτόματα.
########################################

# Ενέσουμε ένα block στο ξεκίνημα της store() (αφήνουμε όλο το υπόλοιπο method ως έχει)
perl -0pi -e '
  s/public function store\(Request \$request\)\s*\{\n/public function store(Request $request)\n    {\n        \/\/ Auto-select MCCMNC when selected network has exactly one MNC and user did not choose it explicitly\n        if (! $request->filled('\''network_mnc_id'\'') && $request->filled('\''network_id'\'')) {\n            $mncIds = \\App\\Models\\NetworkMnc::where('\''network_id'\'', $request->input('\''network_id'\''))->pluck('\''id'\'');\n            if ($mncIds->count() === 1) {\n                $request->merge([\n                    '\''network_mnc_id'\'' => $mncIds->first(),\n                ]);\n            }\n        }\n\n/;
' app/Http/Controllers/OffersController.php

echo "==> Done. Backup stored at: ${BACKUP_DIR}"
