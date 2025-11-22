#!/usr/bin/env bash
set -euo pipefail

##
# wire_product_type_dropdown_v1.sh
#
# 1) Rewrites SupplierConnection model to:
#    - include charge type constants + label accessor
#    - keep product_type string field
# 2) Rewrites SupplierConnectionsController to:
#    - validate product_type
#    - dynamically load Product Type options from dropdown_items for menu id=1
##

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/wire_product_type_dropdown_${STAMP}"
echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "   - Backing up ${f}"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    cp "$f" "${BACKUP_DIR}/${f}"
  fi
}

backup_file "app/Models/SupplierConnection.php"
backup_file "app/Http/Controllers/SupplierConnectionsController.php"

# ---------------------------------------------------------------------------
# 1) SupplierConnection model
# ---------------------------------------------------------------------------
cat > app/Models/SupplierConnection.php << 'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SupplierConnection extends Model
{
    use HasFactory;

    public const CHARGE_TYPE_PER_SUBMIT    = 'per_submit';
    public const CHARGE_TYPE_PER_DELIVERED = 'per_delivered';

    public static function chargeTypeOptions(): array
    {
        return [
            self::CHARGE_TYPE_PER_SUBMIT    => 'Per Submit',
            self::CHARGE_TYPE_PER_DELIVERED => 'Per Delivered',
        ];
    }

    protected $fillable = [
        'supplier_id',
        'name',
        'username',
        'charge_type',
        'product_type',
        'notes',
    ];

    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }

    public function getChargeTypeLabelAttribute(): string
    {
        return static::chargeTypeOptions()[$this->charge_type] ?? (string) $this->charge_type;
    }
}
PHP
echo "==> Rewrote app/Models/SupplierConnection.php"

# ---------------------------------------------------------------------------
# 2) SupplierConnectionsController
# ---------------------------------------------------------------------------
cat > app/Http/Controllers/SupplierConnectionsController.php << 'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\Supplier;
use App\Models\SupplierConnection;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SupplierConnectionsController extends Controller
{
    public function create(Supplier $supplier)
    {
        $productTypeOptions = $this->getProductTypeOptions();

        return view('suppliers.connections.create', [
            'supplier'           => $supplier,
            'productTypeOptions' => $productTypeOptions,
        ]);
    }

    public function store(Request $request, Supplier $supplier)
    {
        $data = $this->validateData($request);

        $connection = new SupplierConnection($data);
        $connection->supplier()->associate($supplier);
        $connection->save();

        return redirect()
            ->route('suppliers.show', $supplier)
            ->with('status', 'Connection created.');
    }

    public function edit(Supplier $supplier, SupplierConnection $connection)
    {
        if ($connection->supplier_id !== $supplier->id) {
            abort(404);
        }

        $productTypeOptions = $this->getProductTypeOptions();

        return view('suppliers.connections.edit', [
            'supplier'           => $supplier,
            'connection'         => $connection,
            'productTypeOptions' => $productTypeOptions,
        ]);
    }

    public function update(Request $request, Supplier $supplier, SupplierConnection $connection)
    {
        if ($connection->supplier_id !== $supplier->id) {
            abort(404);
        }

        $data = $this->validateData($request);

        $connection->update($data);

        return redirect()
            ->route('suppliers.show', $supplier)
            ->with('status', 'Connection updated.');
    }

    public function destroy(Supplier $supplier, SupplierConnection $connection)
    {
        if ($connection->supplier_id !== $supplier->id) {
            abort(404);
        }

        $connection->delete();

        return redirect()
            ->route('suppliers.show', $supplier)
            ->with('status', 'Connection deleted.');
    }

    protected function validateData(Request $request): array
    {
        return $request->validate([
            'name'         => ['required', 'string', 'max:255'],
            'username'     => ['nullable', 'string', 'max:255'],
            'charge_type'  => [
                'required',
                'string',
                'in:' . implode(',', array_keys(SupplierConnection::chargeTypeOptions())),
            ],
            'product_type' => ['nullable', 'string', 'max:255'],
            'notes'        => ['nullable', 'string'],
        ]);
    }

    /**
     * Load Product Type options from the Drop Down Menus.
     *
     * [Inference] We assume:
     *   - Product Type menu is dropdown_menu_id = 1
     *   - Items table is dropdown_items with: id, dropdown_menu_id, label, (optional) position
     * Values stored in SupplierConnection.product_type will be the *label* string.
     */
    protected function getProductTypeOptions(): array
    {
        try {
            $schema = DB::getSchemaBuilder();

            if (! $schema->hasTable('dropdown_items')) {
                return [];
            }

            // menu id 1 = "Product Type" (from /settings/dropdowns/1/items)
            $menuId = 1;

            $query = DB::table('dropdown_items')
                ->where('dropdown_menu_id', $menuId);

            if ($schema->hasColumn('dropdown_items', 'position')) {
                $query->orderBy('position');
            }

            if ($schema->hasColumn('dropdown_items', 'label')) {
                $query->orderBy('label');
            }

            $rows = $query->get();

            $options = [];
            foreach ($rows as $row) {
                $label = $row->label ?? null;
                if ($label === null || $label === '') {
                    continue;
                }

                // Use label both as value and label so old connections display nicely
                $options[$label] = $label;
            }

            return $options;
        } catch (\Throwable $e) {
            // Fail-safe: never break the page because dropdown schema changed
            return [];
        }
    }
}
PHP
echo "==> Rewrote app/Http/Controllers/SupplierConnectionsController.php"

echo "==> Optional syntax check inside container"
if command -v docker >/dev/null 2>&1; then
  docker compose exec -T app bash -lc '
    cd /var/www/html && \
    php -l app/Models/SupplierConnection.php && \
    php -l app/Http/Controllers/SupplierConnectionsController.php
  ' || echo "   (php -l reported an issue or container not running; inspect manually if needed)"
fi

echo "==> Done. Dynamic Product Type dropdown should now be wired."
