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
