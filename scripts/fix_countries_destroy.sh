#!/usr/bin/env bash
set -e

CTRL="app/Http/Controllers/CountriesController.php"
BACKUP_DIR="backup_countries_destroy_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

echo "==> Backing up ${CTRL}"
cp "${CTRL}" "${BACKUP_DIR}/CountriesController.php"

# Αν υπάρχει ήδη destroy(), δεν κάνουμε τίποτα
if grep -q "function destroy(" "${CTRL}"; then
  echo "==> destroy() already exists in CountriesController; nothing to do."
  chmod 644 "${CTRL}" || true
  exit 0
fi

echo "==> Patching CountriesController.php to add destroy()"

tmp="$(mktemp)"

# Βγάζουμε την τελευταία γραμμή (κλείσιμο κλάσης) και την ξαναβάζουμε μόνοι μας στο τέλος
sed '$d' "${CTRL}" > "${tmp}"

cat >> "${tmp}" << 'PHP'

    /**
     * Remove the specified country from storage.
     */
    public function destroy(\App\Models\Country $country)
    {
        $country->delete();

        return redirect()
            ->route('countries.index')
            ->with('status', 'Country deleted.');
    }
}
PHP

mv "${tmp}" "${CTRL}"

echo "==> Fixing permissions on ${CTRL}"
chmod 644 "${CTRL}"

echo "==> Done. CountriesController now has destroy()."
