#!/usr/bin/env bash
set -euo pipefail

echo "==> fix_offers_migrations_and_nav_v1: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/fix_offers_migrations_and_nav_${STAMP}"
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

# Also park any later duplicate offers migrations if they still exist
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

            // NOTE: All foreign keys are plain unsignedBigInteger + index
            // to avoid FK issues with views/materialized relations.
            $table->unsignedBigInteger('country_id')->nullable()->index();
            $table->unsignedBigInteger('network_id')->nullable()->index();
            $table->unsignedBigInteger('network_mnc_id')->nullable()->index();

            $table->unsignedBigInteger('supplier_id')->nullable()->index();
            $table->unsignedBigInteger('supplier_connection_id')->nullable()->index();

            $table->decimal('price', 12, 6);

            $table->string('mcc', 3)->nullable();
            $table->string('mnc', 3)->nullable();
            $table->string('mcc_mnc', 6)->nullable()->index();

            // Product type and other dropdown-driven attributes
            $table->unsignedBigInteger('product_type_id')->nullable()->index();                     // dropdown_items (menu 1)
            $table->unsignedBigInteger('known_hops_dropdown_item_id')->nullable()->index();        // dropdown_items (menu 2)
            $table->unsignedBigInteger('sender_id_supported_dropdown_item_id')->nullable()->index(); // dropdown_items (menu 3)

            // Route & charge model mappings
            $table->unsignedBigInteger('route_type_id')->nullable()->index();   // route_types
            $table->unsignedBigInteger('charge_model_id')->nullable()->index(); // charge_models

            // Charge type (Per Submit / Per Delivered) – maybe overridden vs connection
            $table->string('charge_type', 32)->nullable();

            $table->boolean('is_exclusive')->default(false);

            // Effective date of this price (business date, not created_at)
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

            // Link to the live offer (no DB-level FK, to avoid dependency on table types)
            $table->unsignedBigInteger('supplier_offer_id')->nullable()->index();

            $table->unsignedBigInteger('country_id')->nullable()->index();
            $table->unsignedBigInteger('network_id')->nullable()->index();
            $table->unsignedBigInteger('network_mnc_id')->nullable()->index();

            $table->unsignedBigInteger('supplier_id')->nullable()->index();
            $table->unsignedBigInteger('supplier_connection_id')->nullable()->index();

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

            // When this historic row was recorded into the history
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

echo "==> Clearing caches"
docker compose exec -T app php artisan optimize:clear || true

# --------------------------------------------------------------------
# Add Offers to navigation (desktop + mobile) if missing
# --------------------------------------------------------------------
NAV="resources/views/layouts/navigation.blade.php"
backup_file "$NAV"

if ! grep -q "route('offers.index')" "$NAV"; then
  echo "==> Patching desktop nav to add Offers after Dashboard"
  perl -0pi -e 's#(<x-nav-link :href="route\(\'dashboard\'\)".*?</x-nav-link>)#$1\n\n                    <x-nav-link :href="route(\'offers.index\')" :active="request()->routeIs(\'offers.*\')">\n                        {{ __(\'Offers\') }}\n                    </x-nav-link>#s' "$NAV"

  echo "==> Patching mobile nav to add Offers after Dashboard"
  perl -0pi -e 's#(<x-responsive-nav-link :href="route\(\'dashboard\'\)".*?</x-responsive-nav-link>)#$1\n\n            <x-responsive-nav-link :href="route(\'offers.index\')" :active="request()->routeIs(\'offers.*\')">\n                {{ __(\'Offers\') }}\n            </x-responsive-nav-link>#s' "$NAV"
else
  echo "==> Offers nav entry already present, skipping nav patch"
fi

echo "==> fix_offers_migrations_and_nav_v1: done"
