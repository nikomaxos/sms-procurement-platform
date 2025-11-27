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
