#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_fix_updated_by_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/database/migrations"

###############################################
# 1) Μετακίνηση/backup τυχόν σπασμένων migrations
#    για add_updated_by_to_supplier_offers_table
###############################################
echo "==> Moving any existing *add_updated_by_to_supplier_offers_table* migrations to backup..."

shopt -s nullglob
for f in database/migrations/*add_updated_by_to_supplier_offers_table*.php; do
    echo "   - Moving ${f} -> ${BACKUP_DIR}/database/migrations/"
    mv "$f" "${BACKUP_DIR}/database/migrations/"
done
shopt -u nullglob

###############################################
# 2) Δημιουργία ΝΕΟΥ, καθαρού migration
###############################################
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
        // Αν από άλλο migration υπάρχει ήδη, μην το ξαναφτιάξεις
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

echo "==> Created clean migration: ${MIG_FILE}"

###############################################
# 3) Προσπάθεια εκτέλεσης migration μέσα στο container
###############################################
if command -v docker >/dev/null 2>&1; then
  echo "==> Trying to run migrations via: docker exec sms-platform-app php artisan migrate --force"
  docker exec sms-platform-app php artisan migrate --force || echo "WARN: docker exec failed. Please run the migration manually inside the app container."
else
  echo "WARN: docker binary not found. Please run: php artisan migrate --force inside the app container manually."
fi

echo "==> Done. Backups stored at: ${BACKUP_DIR}"
