#!/usr/bin/env bash
set -euo pipefail

echo "==> add_offers_bulk_update_route_and_method: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/add_offers_bulk_update_${STAMP}"
echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "   - Backing up ${f}"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    cp "$f" "${BACKUP_DIR}/${f}"
  else
    echo "   - WARNING: ${f} not found, nothing to back up"
  fi
}

ROUTES_FILE="routes/web.php"
CONTROLLER_FILE="app/Http/Controllers/OffersController.php"

backup_file "$ROUTES_FILE"
backup_file "$CONTROLLER_FILE"

# -------------------------------------------------------------------
# 1) Route: POST /offers/bulk-update  -> offers.bulk_update
# -------------------------------------------------------------------
if ! grep -q "offers.bulk_update" "$ROUTES_FILE"; then
  echo "==> Adding offers.bulk_update route to routes/web.php"
  cat >> "$ROUTES_FILE" << 'PHP'

Route::post('/offers/bulk-update', [\App\Http\Controllers\OffersController::class, 'bulkUpdate'])
    ->middleware(['auth'])
    ->name('offers.bulk_update');
PHP
else
  echo "==> Route offers.bulk_update already present, skipping."
fi

# -------------------------------------------------------------------
# 2) Controller: add bulkUpdate() if not present
# -------------------------------------------------------------------
if ! grep -q "function bulkUpdate" "$CONTROLLER_FILE"; then
  echo "==> Adding bulkUpdate method to OffersController"

  perl -0pi -e 's#}\s*$#    public function bulkUpdate(\\Illuminate\\Http\\Request $request)\n    {\n        $validated = $request->validate([\n            "selected_offers" => "required|array",\n            "selected_offers.*" => "integer|exists:supplier_offers,id",\n            "known_hops_dropdown_item_id" => "nullable|integer",\n            "sender_id_supported_dropdown_item_id" => "nullable|integer",\n            "charge_model_id" => "nullable|integer",\n            "charge_type" => "nullable|string",\n            "is_exclusive" => "nullable|boolean",\n        ]);\n\n        $ids = $validated["selected_offers"];\n        $updates = [];\n        foreach ([\n            "known_hops_dropdown_item_id",\n            "sender_id_supported_dropdown_item_id",\n            "charge_model_id",\n            "charge_type",\n            "is_exclusive",\n        ] as $field) {\n            if (array_key_exists($field, $validated) && $validated[$field] !== null && $validated[$field] !== "") {\n                $updates[$field] = $validated[$field];\n            }\n        }\n\n        if (!empty($updates)) {\n            \\App\\Models\\SupplierOffer::whereIn("id", $ids)->update($updates);\n        }\n\n        return redirect()->route("offers.index")->with("status", "Selected offers have been updated.");\n    }\n\n}\n#s' "$CONTROLLER_FILE"
else
  echo "==> bulkUpdate method already exists in OffersController, skipping."
fi

echo "==> Clearing route + config cache"
docker compose exec -T app php artisan route:clear || true
docker compose exec -T app php artisan config:clear || true

echo "==> add_offers_bulk_update_route_and_method: done"
