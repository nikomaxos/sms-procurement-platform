<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::hasColumn('supplier_offers', 'route_type')) {
            Schema::table('supplier_offers', function (Blueprint $table) {
                $table->dropColumn('route_type');
            });
        }
    }

    public function down(): void
    {
        if (!Schema::hasColumn('supplier_offers', 'route_type')) {
            Schema::table('supplier_offers', function (Blueprint $table) {
                $table->string('route_type')->nullable();
            });
        }
    }
};
