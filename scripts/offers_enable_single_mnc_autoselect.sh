#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_single_mnc_autoselect_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p \
  "${BACKUP_DIR}/resources/views/offers" \
  "${BACKUP_DIR}/resources/views/offers/partials"

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

if [ -f "resources/views/offers/partials/auto_select_single_mnc.blade.php" ]; then
  cp resources/views/offers/partials/auto_select_single_mnc.blade.php \
     "${BACKUP_DIR}/resources/views/offers/partials/" \
     || echo "WARN: could not backup auto_select_single_mnc.blade.php"
fi

mkdir -p resources/views/offers/partials

########################################
# 2) Γράφουμε ξανά το partial JS
########################################

cat > resources/views/offers/partials/auto_select_single_mnc.blade.php << 'BLADE'
<script>
    document.addEventListener('DOMContentLoaded', function () {
        // Βρίσκουμε τα select του network και του MNC
        const networkSelect = document.querySelector('select[name="network_id"]')
            || document.getElementById('network_id');
        const mncSelect = document.querySelector('select[name="network_mnc_id"]')
            || document.getElementById('network_mnc_id');

        if (!networkSelect || !mncSelect) {
            return;
        }

        function autoSelectSingleMnc() {
            const options = Array.from(mncSelect.options || []);

            // Αγνοούμε κενές / placeholder επιλογές (χωρίς value ή disabled)
            const validOptions = options.filter(function (opt) {
                if (opt.disabled) return false;
                if (opt.value === null || opt.value === undefined) return false;
                if (String(opt.value).trim() === '') return false;
                return true;
            });

            if (validOptions.length === 1) {
                mncSelect.value = validOptions[0].value;
            }
        }

        // Τρέχουμε μία φορά στην αρχική φόρτωση
        setTimeout(autoSelectSingleMnc, 0);

        // Και κάθε φορά που αλλάζει το network
        networkSelect.addEventListener('change', function () {
            // Δίνουμε λίγο χρόνο στο υπόλοιπο JS της σελίδας
            // να κάνει populate το MNC dropdown.
            setTimeout(autoSelectSingleMnc, 0);
        });
    });
</script>
BLADE

########################################
# 3) Βάζουμε το @include στο create.blade.php (αν δεν υπάρχει ήδη)
########################################

CREATE_VIEW="resources/views/offers/create.blade.php"

if grep -q "offers.partials.auto_select_single_mnc" "$CREATE_VIEW"; then
  echo "==> Include for auto_select_single_mnc already present in create.blade.php"
else
  # Αν υπάρχει </x-app-layout>, βάζουμε το include ακριβώς πριν από αυτό
  if grep -q "</x-app-layout>" "$CREATE_VIEW"; then
    perl -0pi -e 's#</x-app-layout>#    @include("offers.partials.auto_select_single_mnc")\n</x-app-layout>#' "$CREATE_VIEW"
    echo "==> Inserted include before </x-app-layout> in create.blade.php"
  else
    # Διαφορετικά, απλά το κάνουμε append στο τέλος του αρχείου
    cat >> "$CREATE_VIEW" << 'EOJS'

{{-- Auto-select single MNC when a network has only one MNC --}}
@include('offers.partials.auto_select_single_mnc')
EOJS
    echo "==> Appended include at end of create.blade.php"
  fi
fi

echo "==> Done. Backup stored at: ${BACKUP_DIR}"
