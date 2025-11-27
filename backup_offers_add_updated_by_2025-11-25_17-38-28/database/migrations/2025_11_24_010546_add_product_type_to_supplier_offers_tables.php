<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Add product_type (string) to supplier_offers if missing
        if (!Schema::hasColumn('supplier_offers', 'product_type')) {
            Schema::table('supplier_offers', function (Blueprint $table) {
                $table->string('product_type', 64)->nullable();
            });
        }

        // Add product_type (string) to supplier_offer_history if missing
        if (!Schema::hasColumn('supplier_offer_history', 'product_type')) {
            Schema::table('supplier_offer_history', function (Blueprint $table) {
                $table->string('product_type', 64)->nullable();
            });
        }
    }

    public function down(): void
    {
        // Drop product_type from supplier_offers if present
        if (Schema::hasColumn('supplier_offers', 'product_type')) {
            Schema::table('supplier_offers', function (Blueprint $table) {
                $table->dropColumn('product_type');
            });
        }

        // Drop product_type from supplier_offer_history if present
        if (Schema::hasColumn('supplier_offer_history', 'product_type')) {
            Schema::table('supplier_offer_history', function (Blueprint $table) {
                $table->dropColumn('product_type');
            });
        }
    }
};
