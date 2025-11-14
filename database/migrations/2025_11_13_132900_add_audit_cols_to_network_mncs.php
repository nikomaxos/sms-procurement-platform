<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        if (Schema::hasTable('network_mncs')) {
            Schema::table('network_mncs', function (Blueprint $t) {
                if (!Schema::hasColumn('network_mncs','created_by_user')) {
                    $t->string('created_by_user', 100)->nullable()->after('mnc');
                }
                if (!Schema::hasColumn('network_mncs','updated_by_user')) {
                    $t->string('updated_by_user', 100)->nullable()->after('created_by_user');
                }
            });
            // safety: ensure mcc not null (fallback to empty string)
            DB::statement("update network_mncs set mcc = coalesce(mcc,'') where mcc is null");
        }
    }
    public function down(): void {
        if (Schema::hasTable('network_mncs')) {
            Schema::table('network_mncs', function (Blueprint $t) {
                if (Schema::hasColumn('network_mncs','updated_by_user')) $t->dropColumn('updated_by_user');
                if (Schema::hasColumn('network_mncs','created_by_user')) $t->dropColumn('created_by_user');
            });
        }
    }
};
