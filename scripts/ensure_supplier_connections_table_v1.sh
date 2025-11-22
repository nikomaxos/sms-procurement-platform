#!/usr/bin/env bash
set -euo pipefail

##
# ensure_supplier_connections_table_v1.sh
#
# Holistic DB fix for Supplier Connections:
# - Adds an idempotent migration that creates the `supplier_connections` table
#   ONLY if it does not already exist.
# - Runs `php artisan migrate` inside the Docker `app` service.
##

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
  pwd
)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/ensure_supplier_connections_table_${STAMP}"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

# Back up any existing supplier_connections migrations (if any)
for f in database/migrations/*supplier_connections*; do
  if [[ -f "$f" ]]; then
    echo "   - Backing up existing migration: $f"
    mkdir -p "${BACKUP_DIR}/database/migrations"
    cp "$f" "${BACKUP_DIR}/database/migrations/$(basename "$f")"
  fi
done

# Create a new guarded migration that will only create the table if missing
MIG_FILE="database/migrations/2025_11_22_170500_create_supplier_connections_table_fix.php"
echo "==> Writing guarded migration: ${MIG_FILE}"
mkdir -p database/migrations
cat > "${MIG_FILE}" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('supplier_connections')) {
            Schema::create('supplier_connections', function (Blueprint $table) {
                $table->id();
                $table->foreignId('supplier_id')->constrained()->cascadeOnDelete();
                $table->string('name');
                $table->string('username')->nullable();
                $table->string('charge_type', 32);
                $table->text('notes')->nullable();
                $table->timestamps();

                $table->index('supplier_id');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_connections');
    }
};
PHP

echo "==> Optional: local PHP syntax check of the migration (if php exists on host)"
if command -v php >/dev/null 2>&1; then
  php -l "${MIG_FILE}" || echo "   (php -l on host reported an issue; migration will still be checked inside container)"
fi

echo "==> Running migrations inside Docker (service: app)"
if command -v docker >/dev/null 2>&1; then
  docker compose exec -T app bash -lc 'cd /var/www/html && php artisan migrate'
else
  echo "ERROR: docker not found on host; please run migrations manually inside the container:"
  echo "  docker compose exec -T app php artisan migrate"
  exit 1
fi

echo "==> Done. supplier_connections table should now exist."
