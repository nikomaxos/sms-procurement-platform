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
