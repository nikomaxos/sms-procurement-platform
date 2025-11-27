#!/usr/bin/env bash
set -euo pipefail

echo "==> reset_offers_migrations_clean: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/reset_offers_migrations_clean_${STAMP}"
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

MIG1="database/migrations/2025_11_23_012523_000000_create_supplier_offers_table.php"
MIG2="database/migrations/2025_11_23_012523_000001_create_supplier_offer_history_table.php"

backup_file "$MIG1"
backup_file "$MIG2"

# Also move any duplicate 012636 migrations out of the way (if they still exist)
for f in \
  "database/migrations/2025_11_23_012636_000000_create_supplier_offers_table.php" \
  "database/migrations/2025_11_23_012636_000001_create_supplier_offer_history_table.php"
do
  if [[ -f "$f" ]]; then
    echo "==> Moving duplicate migration ${f} to backup"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    mv "$f" "${BACKUP_DIR}/${f}"
  fi
done

echo "==> Rewriting ${MIG1}"
cat > "$MIG1" << 'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('supplier_offers', function (Blueprint $table) {
            $table->id();

            // No FK to countries because in this DB 'countries' is not a regular table.
            $table->unsignedBigInteger('country_id')->nullable()->index();

            $table->foreignId('network_id')->constrained()->cascadeOnDelete();
            $table->foreignId('network_mnc_id')->constrained('network_mncs')->cascadeOnDelete();

            $table->foreignId('supplier_id')->constrained('suppliers')->cascadeOnDelete();
            $table->foreignId('supplier_connection_id')->constrained('supplier_connections')->cascadeOnDelete();

            $table->decimal('price', 12, 6);

            $table->string('mcc', 3)->nullable();
            $table->string('mnc', 3)->nullable();
            $table->string('mcc_mnc', 6)->nullable()->index();

            // Business attributes / mappings
            // Product Type, Known Hops, Sender Id Supported come from dropdown_items
            $table->unsignedBigInteger('product_type_id')->nullable()->index();                     // dropdown_items (menu 1)
            $table->unsignedBigInteger('known_hops_dropdown_item_id')->nullable()->index();        // dropdown_items (menu 2)
            $table->unsignedBigInteger('sender_id_supported_dropdown_item_id')->nullable()->index(); // dropdown_items (menu 3)

            // Route & Charge model come from their dedicated tables
            $table->unsignedBigInteger('route_type_id')->nullable()->index();   // route_types
            $table->unsignedBigInteger('charge_model_id')->nullable()->index(); // charge_models

            // Charge type (Per Submit / Per Delivered), decoupled from connection if overridden
            $table->string('charge_type', 32)->nullable();

            $table->boolean('is_exclusive')->default(false);

            // Effective date of this price
            $table->date('effective_date')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offers');
    }
};
PHP

echo "==> Rewriting ${MIG2}"
cat > "$MIG2" << 'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('supplier_offer_history', function (Blueprint $table) {
            $table->id();

            $table->foreignId('supplier_offer_id')
                ->constrained('supplier_offers')
                ->cascadeOnDelete();

            // Same dimensional keys as main offer
            $table->unsignedBigInteger('country_id')->nullable()->index();
            $table->foreignId('network_id')->constrained()->cascadeOnDelete();
            $table->foreignId('network_mnc_id')->constrained('network_mncs')->cascadeOnDelete();

            $table->foreignId('supplier_id')->constrained('suppliers')->cascadeOnDelete();
            $table->foreignId('supplier_connection_id')->constrained('supplier_connections')->cascadeOnDelete();

            $table->decimal('price', 12, 6);

            $table->string('mcc', 3)->nullable();
            $table->string('mnc', 3)->nullable();
            $table->string('mcc_mnc', 6)->nullable()->index();

            $table->unsignedBigInteger('product_type_id')->nullable()->index();
            $table->unsignedBigInteger('known_hops_dropdown_item_id')->nullable()->index();
            $table->unsignedBigInteger('sender_id_supported_dropdown_item_id')->nullable()->index();

            $table->unsignedBigInteger('route_type_id')->nullable()->index();
            $table->unsignedBigInteger('charge_model_id')->nullable()->index();

            $table->string('charge_type', 32)->nullable();
            $table->boolean('is_exclusive')->default(false);

            $table->date('effective_date')->nullable();

            // When this historic row was recorded
            $table->timestamp('recorded_at')->useCurrent();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offer_history');
    }
};
PHP

echo "==> New supplier_offers migration snippet:"
sed -n '8,40p' "$MIG1" || true

echo "==> New supplier_offer_history migration snippet:"
sed -n '8,40p' "$MIG2" || true

echo "==> Running migrations..."
docker compose exec -T app php artisan migrate --force

echo '==> Clearing caches'
docker compose exec -T app php artisan optimize:clear || true

echo "==> reset_offers_migrations_clean: done"
