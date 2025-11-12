<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (Schema::hasTable('imap_settings') && !Schema::hasColumn('imap_settings','last_run_at')) {
            Schema::table('imap_settings', function (Blueprint $table) {
                $table->timestamp('last_run_at')->nullable()->after('last_test_log');
            });
        }
    }
    public function down(): void {
        if (Schema::hasTable('imap_settings') && Schema::hasColumn('imap_settings','last_run_at')) {
            Schema::table('imap_settings', function (Blueprint $table) {
                $table->dropColumn('last_run_at');
            });
        }
    }
};
