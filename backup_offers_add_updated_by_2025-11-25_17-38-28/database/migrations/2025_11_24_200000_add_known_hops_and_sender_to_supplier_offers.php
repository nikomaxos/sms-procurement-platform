<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('supplier_offers', function (Blueprint $table) {
            if (!Schema::hasColumn('supplier_offers', 'known_hops')) {
                $table->string('known_hops')->nullable()->after('product_type');
            }
            if (!Schema::hasColumn('supplier_offers', 'sender_id_supported')) {
                $table->string('sender_id_supported')->nullable()->after('known_hops');
            }
        });
    }

    public function down(): void
    {
        Schema::table('supplier_offers', function (Blueprint $table) {
            if (Schema::hasColumn('supplier_offers', 'sender_id_supported')) {
                $table->dropColumn('sender_id_supported');
            }
            if (Schema::hasColumn('supplier_offers', 'known_hops')) {
                $table->dropColumn('known_hops');
            }
        });
    }
};
