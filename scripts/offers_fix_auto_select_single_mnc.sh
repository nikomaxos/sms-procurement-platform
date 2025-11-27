#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_fix_auto_select_single_mnc_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/resources/views/offers/partials"

# Backup existing partial if present
if [ -f "resources/views/offers/partials/auto_select_single_mnc.blade.php" ]; then
  cp resources/views/offers/partials/auto_select_single_mnc.blade.php \
     "${BACKUP_DIR}/resources/views/offers/partials/" \
     || echo "WARN: could not backup auto_select_single_mnc.blade.php"
fi

cat > resources/views/offers/partials/auto_select_single_mnc.blade.php << 'BLADE'
<script>
    document.addEventListener('DOMContentLoaded', function () {
        // Πιάνουμε τα selects με βάση το name, όχι το id
        const networkSelect = document.querySelector('select[name="network_id"]');
        const mncSelect     = document.querySelector('select[name="network_mnc_id"]');

        if (!networkSelect || !mncSelect) {
            return;
        }

        function autoSelectSingleMnc() {
            const options = Array.from(mncSelect.options || []);

            // Αγνοούμε placeholder/κενές τιμές
            const validOptions = options.filter(function (opt) {
                return opt.value !== '' && opt.value != null;
            });

            if (validOptions.length === 1) {
                mncSelect.value = validOptions[0].value;
            }
        }

        // Στην αρχική φόρτωση (αν ήδη έχει γίνει populate MNCs)
        setTimeout(autoSelectSingleMnc, 0);

        // Κάθε φορά που αλλάζει το network:
        // Δίνουμε ένα μικρό delay ώστε να προλάβει το υπάρχον JS
        // να κάνει populate τα MNCs και μετά εμείς να δούμε πόσα έμειναν.
        networkSelect.addEventListener('change', function () {
            setTimeout(autoSelectSingleMnc, 50);
        });
    });
</script>
BLADE

echo "==> Updated auto_select_single_mnc partial. Backup at: ${BACKUP_DIR}"
