<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('supplier_connections', 'connection_dead')) {
            Schema::table('supplier_connections', function (Blueprint $table) {
                $table->boolean('connection_dead')
                    ->default(false)
                    ->after('product_type');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('supplier_connections', 'connection_dead')) {
            Schema::table('supplier_connections', function (Blueprint $table) {
                $table->dropColumn('connection_dead');
            });
        }
    }
};
