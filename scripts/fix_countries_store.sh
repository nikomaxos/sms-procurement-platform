#!/usr/bin/env bash
set -e

CTRL="app/Http/Controllers/CountriesController.php"
BACKUP_DIR="backup_countries_store_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

echo "==> Backing up ${CTRL}"
cp "${CTRL}" "${BACKUP_DIR}/CountriesController.php"

# Αν υπάρχει ήδη store(), δεν κάνουμε τίποτα
if grep -q "function store(" "${CTRL}"; then
  echo "==> store() already exists in CountriesController; nothing to do."
  chmod 644 "${CTRL}" || true
  exit 0
fi

echo "==> Patching CountriesController.php to add store()"

tmp="$(mktemp)"

# Βγάζουμε την τελευταία γραμμή (κλείσιμο κλάσης) και την ξαναβάζουμε μόνοι μας στο τέλος
sed '$d' "${CTRL}" > "${tmp}"

cat >> "${tmp}" << 'PHP'

    /**
     * Store a newly created country.
     */
    public function store(\Illuminate\Http\Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'iso2' => 'nullable|string|max:2',
        ]);

        $country = new \App\Models\Country();
        $country->name = $data['name'];

        if (!empty($data['iso2'])) {
            $country->iso2 = strtoupper($data['iso2']);
        }

        $country->save();

        return redirect()
            ->route('countries.index')
            ->with('status', 'Country created.');
    }
}
PHP

mv "${tmp}" "${CTRL}"

echo "==> Fixing permissions on ${CTRL}"
chmod 644 "${CTRL}"

echo "==> Done. CountriesController now has store()."
