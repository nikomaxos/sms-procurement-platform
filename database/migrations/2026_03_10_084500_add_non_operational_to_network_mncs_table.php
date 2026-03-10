<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('network_mncs', function (Blueprint $table) {
            $table->boolean('non_operational')->default(false)->after('mcc_mnc');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('network_mncs', function (Blueprint $table) {
            $table->dropColumn('non_operational');
        });
    }
};
