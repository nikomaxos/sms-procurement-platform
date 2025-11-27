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
