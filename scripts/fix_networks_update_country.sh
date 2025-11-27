#!/usr/bin/env bash
set -e

CTRL="app/Http/Controllers/NetworksController.php"
BACKUP_DIR="backup_networks_update_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"
cp "${CTRL}" "${BACKUP_DIR}/NetworksController.php"

echo "==> Patching NetworksController::update() to force DB country_id update"

tmp="$(mktemp)"

awk '
BEGIN { in_update = 0; }
/public function update\(Request \$request, Network \$network\)/ {
    in_update = 1;
    print "    public function update(Request $request, Network $network)";
    print "    {";
    print "        $data = $request->validate([";
    print "            '\''country_id'\''      => '\''required|integer|exists:countries,id'\'',";
    print "            '\''name'\''            => '\''required|string|max:255'\'',";
    print "            '\''notes'\''           => '\''nullable|string'\'',";
    print "            '\''non_operational'\'' => '\''nullable'\'',";
    print "            '\''mncs'\''            => '\''array'\'',";
    print "            '\''mncs.*.mcc'\''      => '\''nullable|string'\'',";
    print "            '\''mncs.*.mnc'\''      => ['\''nullable'\'', '\''regex:/^\\d{2,3}$/\''],";
    print "        ]);";
    print "";
    print "        $countryId = (int) $data['\''country_id'\''];";
    print "";
    print "        $payload = [";
    print "            '\''country_id'\'' => $countryId,";
    print "            '\''name'\''       => $data['\''name'\''],";
    print "            '\''updated_at'\'' => now(),";
    print "        ];";
    print "";
    print "        if (schema_has_column('\''networks'\'', '\''lower_name'\'')) {";
    print "            $payload['\''lower_name'\''] = Str::lower($data['\''name'\'']);";
    print "        }";
    print "";
    print "        DB::table('\''networks'\'')";
    print "            ->where('\''id'\'', $network->id)";
    print "            ->update($payload);";
    print "";
    print "        // Reload model so relations/meta see fresh DB values";
    print "        $network->refresh();";
    print "";
    print "        $notes = isset($data['\''notes'\'']) ? trim((string) $data['\''notes'\'']) : '\'''\'';"; 
    print "        $nonOperational = $request->boolean('\''non_operational'\'');";
    print "";
    print "        $meta = NetworkMeta::firstOrNew(['\''network_id'\'' => $network->id]);";
    print "        $meta->non_operational = $nonOperational;";
    print "        $meta->notes           = $notes !== '\'''\'' ? $notes : null;";
    print "";
    print "        if ($notes === '\'''\'' && !$nonOperational && $meta->exists) {";
    print "            $meta->notes = null;";
    print "        }";
    print "";
    print "        $meta->save();";
    print "";
    print "        $this->syncMncs($network, $data['\''mncs'\''] ?? []);";
    print "";
    print "        return back()->with('\''status'\'', '\''Network saved.'\'');";
    print "    }";
    next;
}
/protected function syncMncs\(Network \$network, \?array \$mncs\): void/ {
    in_update = 0;
    print "";
    print $0;
    next;
}
!in_update { print }
' "${CTRL}" > "${tmp}"

mv "${tmp}" "${CTRL}"
chmod 644 "${CTRL}" || true

echo "==> Done. NetworksController::update() patched."
