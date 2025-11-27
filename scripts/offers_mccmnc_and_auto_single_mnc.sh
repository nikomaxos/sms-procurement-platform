#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_mccmnc_and_auto_single_mnc_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p \
  "${BACKUP_DIR}/resources/views/offers" \
  "${BACKUP_DIR}/app/Models"

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

if [ -f "app/Models/SupplierOffer.php" ]; then
  cp app/Models/SupplierOffer.php "${BACKUP_DIR}/app/Models/" \
    || echo "WARN: could not backup SupplierOffer.php"
else
  echo "!! app/Models/SupplierOffer.php not found. Aborting."
  exit 1
fi

########################################
# 2) Views: κάνε το πεδίο να φαίνεται ως MCCMNC
#    - αλλάζουμε το label από "MNC" σε "MCCMNC"
#    - όπου υπάρχει $something->mnc στο dropdown, το κάνουμε ->mcc_mnc
########################################

# Label text MNC -> MCCMNC στα create/edit
perl -pi -e 's/>MNC</>MCCMNC</g' resources/views/offers/create.blade.php || true
perl -pi -e 's/>MNC</>MCCMNC</g' resources/views/offers/edit.blade.php   || true

# Option texts που δείχνουν μόνο MNC -> δείξε mcc_mnc
perl -pi -e 's/->mnc\b/->mcc_mnc/g' resources/views/offers/create.blade.php || true
perl -pi -e 's/->mnc\b/->mcc_mnc/g' resources/views/offers/edit.blade.php   || true

########################################
# 3) Model: auto-fill network_mnc_id όταν το network έχει 1 μόνο MNC
########################################

SUPPLIER_MODEL="app/Models/SupplierOffer.php"

# Αν υπάρχει ήδη booted() στο model, ΔΕΝ θα πειράξουμε τίποτα για να μην το σπάσουμε.
if grep -q "booted\s*(" "$SUPPLIER_MODEL"; then
  echo "==> SupplierOffer already has a booted() method; skipping auto-fill injection to avoid conflicts."
  echo "   (If θες, μπορούμε μετά να το ενώσουμε χειροκίνητα πάνω στο υπάρχον booted().)"
else
  echo "==> Injecting protected static function booted() into SupplierOffer model..."

  # Βάζουμε το booted() αμέσως μετά το "use HasFactory;"
  perl -0pi -e '
    s/(use HasFactory;\s*\n)/$1\n    protected static function booted()\n    {\n        static::creating(function (self $offer) {\n            if (! $offer->network_mnc_id && $offer->network_id) {\n                $mncIds = \\App\\Models\\NetworkMnc::where("network_id", $offer->network_id)->pluck("id");\n                if ($mncIds->count() === 1) {\n                    $offer->network_mnc_id = $mncIds->first();\n                }\n            }\n        });\n    }\n\n/;
  ' "$SUPPLIER_MODEL" || echo "WARN: could not inject booted() into SupplierOffer.php (pattern not found)."
fi

echo "==> Done. Backup stored at: ${BACKUP_DIR}"
