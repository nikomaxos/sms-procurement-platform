<script>
(function () {
    function initAutoSelectSingleMccMnc() {
        // Το select για MCCMNC
        var mncSelect =
            document.querySelector('select[name="network_mnc_id"]') ||
            document.getElementById('network_mnc_id');

        if (!mncSelect) {
            return;
        }

        function getValidOptions() {
            var options = Array.prototype.slice.call(mncSelect.options || []);
            return options.filter(function (opt) {
                if (opt.disabled) return false;
                if (opt.value === null || opt.value === undefined) return false;
                if (String(opt.value).trim() === '') return false;
                return true;
            });
        }

        function isPlaceholderSelected() {
            var val = mncSelect.value;
            if (val === null || val === undefined) return true;
            if (String(val).trim() === '') return true;

            var selectedOption = mncSelect.options[mncSelect.selectedIndex];
            if (!selectedOption) return true;
            if (selectedOption.disabled) return true;

            return false;
        }

        function autoSelectSingleMnc() {
            var validOptions = getValidOptions();

            // Αν υπάρχει μόνο μία πραγματική επιλογή και είμαστε ακόμα σε placeholder/κενό, διάλεξέ την.
            if (validOptions.length === 1 && isPlaceholderSelected()) {
                mncSelect.value = validOptions[0].value;
                var evt = new Event('change', { bubbles: true });
                mncSelect.dispatchEvent(evt);
            }
        }

        // 1) MutationObserver στα options (childList)
        var observer = new MutationObserver(function () {
            autoSelectSingleMnc();
        });
        observer.observe(mncSelect, { childList: true });

        // 2) Για τα πρώτα ~2 δευτερόλεπτα, δοκίμαζε κάθε 200ms
        var startTime = Date.now();
        var interval = setInterval(function () {
            autoSelectSingleMnc();
            if (!isPlaceholderSelected()) {
                clearInterval(interval);
            } else if (Date.now() - startTime > 2000) {
                clearInterval(interval);
            }
        }, 200);

        // 3) Αν αλλάξει το network και καθαρίσουν τα options, όταν ξαναγεμίσουν θα ενεργοποιηθεί ο observer.
        // Δεν χρειάζεται έξτρα binding εδώ, μιας και ο observer ακούει τα children του select MCCMNC.

        // 4) Τρέξτο και μία φορά στην αρχή
        autoSelectSingleMnc();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initAutoSelectSingleMccMnc);
    } else {
        initAutoSelectSingleMccMnc();
    }
})();
</script>
