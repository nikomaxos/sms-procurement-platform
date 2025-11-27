#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_autofill_single_mccmnc_in_store_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/app/Http/Controllers"

CTRL_FILE="app/Http/Controllers/OffersController.php"

if [ ! -f "$CTRL_FILE" ]; then
  echo "!! $CTRL_FILE not found. Aborting."
  exit 1
fi

# Backup τωρινού controller
cp "$CTRL_FILE" "${BACKUP_DIR}/app/Http/Controllers/" \
  || echo "WARN: could not backup OffersController.php"

#####################################################
# 1) Αν υπάρχει ήδη ensureNetworkMncForRequest(), δεν ξαναπειράζουμε τίποτα
#####################################################
if grep -q "ensureNetworkMncForRequest" "$CTRL_FILE"; then
  echo "==> ensureNetworkMncForRequest() already present in OffersController. Skipping injection."
  echo "==> Backup only. Nothing else changed."
  exit 0
fi

#####################################################
# 2) Κάνε inject κλήση στη helper στην αρχή της store()
#####################################################
# Βάζουμε την κλήση ακριβώς μετά το άνοιγμα της store:
# public function store(Request $request)
# {
#     $this->ensureNetworkMncForRequest($request);
#
perl -0pi -e '
  s/public function store\(Request \$request\)\s*\{\s*/public function store(Request $request)\n    {\n        $this->ensureNetworkMncForRequest($request);\n\n/
' "$CTRL_FILE"

#####################################################
# 3) Προσθήκη της helper μεθόδου στο τέλος της κλάσης
#####################################################
perl -0pi -e '
  s#\n}\s*$#\n    protected function ensureNetworkMncForRequest(\\Illuminate\\Http\\Request $request)\n    {\n        // Αν δεν έχει σταλεί network_mnc_id αλλά υπάρχει network_id,\n        // και το δίκτυο έχει ακριβώς ένα MCCMNC, το συμπληρώνουμε αυτόματα.\n        if (! $request->filled('\''network_mnc_id'\'') && $request->filled('\''network_id'\'')) {\n            $mncIds = \\App\\Models\\NetworkMnc::where('\''network_id'\'', $request->input('\''network_id'\''))->pluck('\''id'\'');\n            if ($mncIds->count() === 1) {\n                $request->merge([\n                    '\''network_mnc_id'\'' => $mncIds->first(),\n                ]);\n            }\n        }\n    }\n\n}\n#' "$CTRL_FILE"

echo "==> Done. OffersController updated with backend auto-fill for single-MCCMNC networks."
echo "==> Backup of previous controller at: ${BACKUP_DIR}"
