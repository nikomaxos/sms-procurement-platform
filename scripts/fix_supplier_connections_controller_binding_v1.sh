#!/usr/bin/env bash
set -euo pipefail

##
# fix_supplier_connections_controller_binding_v1.sh
#
# Holistic fix for:
#   Target class [SupplierConnectionsController] does not exist.
#
# It:
#   - Backs up routes/web.php and SupplierConnectionsController.php
#   - Rewrites app/Http/Controllers/SupplierConnectionsController.php to a clean,
#     valid, namespaced controller.
#   - Replaces any bare "SupplierConnectionsController::class" with the fully
#     qualified "\App\Http\Controllers\SupplierConnectionsController::class"
#   - Rewrites any string-style "SupplierConnectionsController@..." actions to
#     "App\Http\Controllers\SupplierConnectionsController@..."
##

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
  pwd
)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/fix_supplier_connections_controller_${STAMP}"

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

ROUTES_FILE="routes/web.php"
CTRL_FILE="app/Http/Controllers/SupplierConnectionsController.php"

backup_file "$ROUTES_FILE"
backup_file "$CTRL_FILE"

echo "==> Rewriting SupplierConnectionsController to a clean, valid class"
mkdir -p app/Http/Controllers
cat > "$CTRL_FILE" <<'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\Supplier;
use App\Models\SupplierConnection;
use Illuminate\Http\Request;

class SupplierConnectionsController extends Controller
{
    protected function validateData(Request $request): array
    {
        return $request->validate([
            'name'        => ['required', 'string', 'max:255'],
            'username'    => ['nullable', 'string', 'max:255'],
            'charge_type' => [
                'required',
                'string',
                'in:' . implode(',', array_keys(SupplierConnection::CHARGE_TYPE_OPTIONS)),
            ],
            'notes'       => ['nullable', 'string'],
        ]);
    }

    public function create(Supplier $supplier)
    {
        return view('suppliers.connections.create', [
            'supplier' => $supplier,
        ]);
    }

    public function store(Request $request, Supplier $supplier)
    {
        $data = $this->validateData($request);

        $supplier->connections()->create($data);

        return redirect()
            ->route('suppliers.show', $supplier)
            ->with('status', 'Connection created.');
    }

    public function edit(Supplier $supplier, SupplierConnection $connection)
    {
        if ($connection->supplier_id !== $supplier->id) {
            abort(404);
        }

        return view('suppliers.connections.edit', [
            'supplier'   => $supplier,
            'connection' => $connection,
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
}
PHP

echo "==> Patching routes/web.php to use fully qualified controller name"

# 1) Class-constant style: SupplierConnectionsController::class
perl -0pi -e '
    s/SupplierConnectionsController::class/\\App\\Http\\Controllers\\SupplierConnectionsController::class/g
' "$ROUTES_FILE"

# 2) String-style actions: 'SupplierConnectionsController@...' or "SupplierConnectionsController@..."
perl -0pi -e '
    s/'\''SupplierConnectionsController@/'\''App\\Http\\Controllers\\SupplierConnectionsController@/g;
    s/"SupplierConnectionsController@/"App\\Http\\Controllers\\SupplierConnectionsController@/g;
' "$ROUTES_FILE"

echo "==> Optional: php -l (syntax check) on controller and routes inside app container"
if command -v docker >/dev/null 2>&1; then
  docker compose exec -T app bash -lc '
    cd /var/www/html && \
    php -l app/Http/Controllers/SupplierConnectionsController.php && \
    php -l routes/web.php
  ' || echo "   (php -l reported an issue or container not running; inspect files if needed)"
fi

echo "==> Done. SupplierConnectionsController should now be resolvable by the container."
