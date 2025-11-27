#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_add_updated_by_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/database/migrations"

# Προαιρετικό backup σχετικών migrations (αν υπάρχουν)
cp database/migrations/*supplier_offers* "${BACKUP_DIR}/database/migrations/" 2>/dev/null || true

# Δημιουργία νέου migration με timestamp
MIG_TS=$(date +%Y_%m_%d_%H%M%S)
MIG_FILE="database/migrations/${MIG_TS}_add_updated_by_to_supplier_offers_table.php"

cat > "${MIG_FILE}" << 'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Προστασία αν υπάρχει ήδη η στήλη από άλλο migration
        if (!Schema::hasColumn('supplier_offers', 'updated_by')) {
            Schema::table('supplier_offers', function (Blueprint $table) {
                $table->foreignId('updated_by')
                    ->nullable()
                    ->after('product_type')
                    ->constrained('users')
                    ->nullOnDelete();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('supplier_offers', 'updated_by')) {
            Schema::table('supplier_offers', function (Blueprint $table) {
                $table->dropForeign(['updated_by']);
                $table->dropColumn('updated_by');
            });
        }
    }
};
PHP

echo "==> Created migration: ${MIG_FILE}"
echo "============================================================"
echo "Now run the migration inside your app container, for example:"
echo ""
echo "  docker compose exec sms-platform-app php artisan migrate --force"
echo ""
echo "Adjust the command if you use a different docker compose syntax."
echo "============================================================"
