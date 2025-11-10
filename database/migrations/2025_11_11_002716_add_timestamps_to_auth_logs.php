<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
        // Add timestamps only if they don't already exist
        Schema::table('auth_logs', function (Blueprint $table) {
            if (! Schema::hasColumn('auth_logs', 'created_at')) {
                $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
            }
            if (! Schema::hasColumn('auth_logs', 'updated_at')) {
                // Postgres doesn't support ON UPDATE CURRENT_TIMESTAMP; Eloquent will manage updates.
                $table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP'));
            }
        });
    }

    public function down(): void
    {
        Schema::table('auth_logs', function (Blueprint $table) {
            if (Schema::hasColumn('auth_logs', 'created_at')) {
                $table->dropColumn('created_at');
            }
            if (Schema::hasColumn('auth_logs', 'updated_at')) {
                $table->dropColumn('updated_at');
            }
        });
    }
};
