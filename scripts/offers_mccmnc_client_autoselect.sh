#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_mccmnc_client_autoselect_$(date +%F_%H-%M-%S)"

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

if [ -f "resources/views/offers/edit.blade.php" ]; then
  cp resources/views/offers/edit.blade.php "${BACKUP_DIR}/resources/views/offers/" \
    || echo "WARN: could not backup edit.blade.php"
fi

if [ -f "resources/views/offers/partials/auto_select_single_mnc.blade.php" ]; then
  cp resources/views/offers/partials/auto_select_single_mnc.blade.php \
     "${BACKUP_DIR}/resources/views/offers/partials/" \
     || echo "WARN: could not backup auto_select_single_mnc.blade.php"
fi

mkdir -p resources/views/offers/partials

########################################
# 2) Νέο partial με MutationObserver
########################################

cat > resources/views/offers/partials/auto_select_single_mnc.blade.php << 'BLADE'
<script>
    document.addEventListener('DOMContentLoaded', function () {
        // Βρίσκουμε το select MCCMNC (network_mnc_id)
        var mncSelect =
            document.querySelector('select[name="network_mnc_id"]') ||
            document.getElementById('network_mnc_id');

        if (!mncSelect) {
            return;
        }

        function autoSelectSingleMnc() {
            var options = Array.prototype.slice.call(mncSelect.options || []);

            // Αγνοούμε placeholder / disabled / κενές τιμές
            var validOptions = options.filter(function (opt) {
                if (opt.disabled) return false;
                if (opt.value === null || opt.value === undefined) return false;
                if (String(opt.value).trim() === '') return false;
                return true;
            });

            if (validOptions.length === 1) {
                mncSelect.value = validOptions[0].value;
            }
        }

        // Τρέχουμε μία φορά τώρα (αν είναι ήδη γεμισμένο)
        autoSelectSingleMnc();

        // Παρακολουθούμε αλλαγές στα children (options) του select
        var observer = new MutationObserver(function (mutationsList) {
            autoSelectSingleMnc();
        });

        observer.observe(mncSelect, { childList: true });
    });
</script>
BLADE

########################################
# 3) Include partial σε create & edit αν δεν υπάρχει ήδη
########################################

CREATE_VIEW="resources/views/offers/create.blade.php"
EDIT_VIEW="resources/views/offers/edit.blade.php"

# helper function (bash style) για insert πριν το </x-app-layout> ή στο τέλος
insert_include() {
  local FILE="$1"
  if grep -q "offers.partials.auto_select_single_mnc" "$FILE"; then
    echo "==> Include already present in $FILE"
    return
  fi

  if grep -q "</x-app-layout>" "$FILE"; then
    perl -0pi -e 's#</x-app-layout>#    @include("offers.partials.auto_select_single_mnc")\n</x-app-layout>#' "$FILE"
    echo "==> Inserted include before </x-app-layout> in $FILE"
  else
    cat >> "$FILE" << 'EOINC'

{{-- Auto-select single MCCMNC when a network has only one MNC --}}
@include('offers.partials.auto_select_single_mnc')
EOINC
    echo "==> Appended include at end of $FILE"
  fi
}

insert_include "$CREATE_VIEW"

if [ -f "$EDIT_VIEW" ]; then
  insert_include "$EDIT_VIEW"
fi

echo "==> Done. Backup stored at: ${BACKUP_DIR}"
