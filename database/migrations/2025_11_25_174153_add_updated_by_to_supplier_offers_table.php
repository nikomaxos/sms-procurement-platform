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
