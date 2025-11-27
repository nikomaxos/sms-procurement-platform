#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_auto_select_mnc_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p \
  "${BACKUP_DIR}/resources/views/offers" \
  "${PROJECT_ROOT}/resources/views/offers/partials"

# Backup create view
if [ -f "resources/views/offers/create.blade.php" ]; then
  cp resources/views/offers/create.blade.php "${BACKUP_DIR}/resources/views/offers/" \
    || echo "WARN: could not backup create.blade.php"
else
  echo "!! resources/views/offers/create.blade.php not found. Aborting."
  exit 1
fi

########################################
# 1) Create partial with JS logic
########################################

cat > resources/views/offers/partials/auto_select_single_mnc.blade.php << 'BLADE'
<script>
    document.addEventListener('DOMContentLoaded', function () {
        const networkSelect = document.getElementById('network_id');
        const mncSelect     = document.getElementById('network_mnc_id');

        if (!networkSelect || !mncSelect) {
            return;
        }

        function autoSelectSingleMnc() {
            // Πάρε όλα τα options που έχουν value (αγνόησε την κενή επιλογή)
            const validOptions = Array.from(mncSelect.options).filter(function (opt) {
                return opt.value !== '';
            });

            if (validOptions.length === 1) {
                mncSelect.value = validOptions[0].value;
            }
        }

        // Τρέξ' το αρχικά (σε περίπτωση που η φόρμα φορτώσει ήδη με 1 MNC)
        setTimeout(autoSelectSingleMnc, 0);

        // Και κάθε φορά που αλλάζει το network
        networkSelect.addEventListener('change', function () {
            // Μικρό delay ώστε να προλάβει το υπάρχον script να ενημερώσει το dropdown MNC
            setTimeout(autoSelectSingleMnc, 0);
        });
    });
</script>
BLADE

########################################
# 2) Insert @include in create.blade.php
########################################

# Βάζουμε το include ακριβώς πριν το κλείσιμο </x-app-layout>
perl -0pi -e 's#</x-app-layout>#    @include("offers.partials.auto_select_single_mnc")\n</x-app-layout>#' resources/views/offers/create.blade.php

echo "==> Done. Backup stored at: ${BACKUP_DIR}"
