#!/usr/bin/env bash
set -e

CTRL="app/Http/Controllers/NetworksController.php"
BACKUP_DIR="backup_networks_update_reset_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"
cp "${CTRL}" "${BACKUP_DIR}/NetworksController.php"

echo "==> Restoring a clean, valid update() method in NetworksController"

perl -0pi -e 's#public function update\(Request \$request, Network \$network\).*?protected function syncMncs#public function update(Request $request, Network $network)
    {
        $data = $request->validate([
            '\''country_id'\''      => '\''required|integer|exists:countries,id'\'',
            '\''name'\''            => '\''required|string|max:255'\'',
            '\''notes'\''           => '\''nullable|string'\'',
            '\''non_operational'\'' => '\''nullable'\'',
            '\''mncs'\''            => '\''array'\'',
            '\''mncs.*.mcc'\''      => '\''nullable|string'\'',
            // ENFORCE: 2 or 3 digits only
            '\''mncs.*.mnc'\''      => ['\''nullable'\'', '\''regex:/^\\d{2,3}$/\''],
        ]);

        $network->country_id = (int) $data['\''country_id'\''];
        $network->name       = $data['\''name'\''];

        if (schema_has_column('\''networks'\'', '\''lower_name'\'')) {
            $network->lower_name = Str::lower($data['\''name'\'']);
        }

        $network->save();

        $notes = isset($data['\''notes'\'']) ? trim((string) $data['\''notes'\'']) : '\''\'';
        $nonOperational = $request->boolean('\''non_operational'\'');

        $meta = NetworkMeta::firstOrNew(['\''network_id'\'' => $network->id]);
        $meta->non_operational = $nonOperational;
        $meta->notes           = $notes !== '\''\'' ? $notes : null;

        if ($notes === '\''\'' && !$nonOperational && $meta->exists) {
            $meta->notes = null;
        }

        $meta->save();

        $this->syncMncs($network, $data['\''mncs'\''] ?? []);

        return back()->with('\''status'\'', '\''Network saved.'\'');
    }

    protected function syncMncs#s' "${CTRL}"

chmod 644 "${CTRL}" || true

echo "==> Done. NetworksController::update() restored."
