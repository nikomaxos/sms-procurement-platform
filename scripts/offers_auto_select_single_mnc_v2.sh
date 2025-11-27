#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_auto_select_single_mnc_v2_$(date +%F_%H-%M-%S)"

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
        /**
         * Βρίσκει το MNC <select> με πιο "χαλαρό" τρόπο,
         * ώστε να δουλεύει ανεξάρτητα από το ακριβές name/id.
         */
        function findMncSelect() {
            let sel =
                document.querySelector('select[name="network_mnc_id"]') ||
                document.querySelector('#network_mnc_id');

            if (sel) {
                return sel;
            }

            // fallback: ψάξε οποιοδήποτε <select> που στο name ή id έχει "mnc"
            const candidates = Array.from(document.querySelectorAll('select'));
            return candidates.find(function (el) {
                const n = (el.name || '').toLowerCase();
                const i = (el.id || '').toLowerCase();
                return n.includes('mnc') || i.includes('mnc');
            }) || null;
        }

        /**
         * Αν υπάρχει μόνο 1 valid option (μη κενό), κάνε το auto-select.
         */
        function autoSelectSingleMnc(select) {
            if (!select) return;

            const options = Array.from(select.options || []);

            const validOptions = options.filter(function (opt) {
                // αγνοούμε κενά / placeholder
                return opt.value !== '' && opt.value != null;
            });

            if (validOptions.length === 1) {
                select.value = validOptions[0].value;
            }
        }

        let mncSelect = findMncSelect();
        if (!mncSelect) {
            // αν δεν υπάρχει ακόμη (π.χ. σε SPA render), δοκίμασε αργότερα
            setTimeout(function () {
                mncSelect = findMncSelect();
                if (mncSelect) {
                    autoSelectSingleMnc(mncSelect);
                    attachMncObserver(mncSelect);
                }
            }, 100);
        } else {
            autoSelectSingleMnc(mncSelect);
            attachMncObserver(mncSelect);
        }

        /**
         * Παρακολουθεί το MNC <select> για αλλαγές στα options (childList)
         * και κάθε φορά που αλλάζουν, ξανα-τρέχει την autoSelectSingleMnc.
         */
        function attachMncObserver(select) {
            if (!select) return;

            const observer = new MutationObserver(function () {
                autoSelectSingleMnc(select);
            });

            observer.observe(select, { childList: true });

            // Αν για κάποιο λόγο το <select> αντικατασταθεί ολόκληρο,
            // παρατηρούμε και το body για να ξανα-βρούμε το νέο element.
            const bodyObserver = new MutationObserver(function (mutations) {
                let shouldReattach = false;

                mutations.forEach(function (m) {
                    m.addedNodes.forEach(function (node) {
                        if (
                            node.nodeType === 1 &&
                            node.tagName === 'SELECT' &&
                            ((node.name || '').toLowerCase().includes('mnc') ||
                             (node.id || '').toLowerCase().includes('mnc'))
                        ) {
                            shouldReattach = true;
                        }
                    });
                });

                if (shouldReattach) {
                    const freshSelect = findMncSelect();
                    if (freshSelect && freshSelect !== select) {
                        autoSelectSingleMnc(freshSelect);
                        attachMncObserver(freshSelect);
                    }
                }
            });

            bodyObserver.observe(document.body, { childList: true, subtree: true });
        }
    });
</script>
BLADE

echo "==> Updated auto_select_single_mnc partial. Backup at: ${BACKUP_DIR}"
