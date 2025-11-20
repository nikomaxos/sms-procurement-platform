<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasColumn('networks','lower_name')) {
            Schema::table('networks', function (Blueprint $table) {
                $table->string('lower_name')->nullable()->index();
            });
            // Backfill
            DB::statement('UPDATE networks SET lower_name = LOWER(name) WHERE lower_name IS NULL');
            // (Index is already added above; avoid unique to prevent failures on legacy dupes)
        } else {
            // Ensure any nulls are backfilled
            DB::statement('UPDATE networks SET lower_name = LOWER(name) WHERE lower_name IS NULL');
        }
    }
    public function down(): void {
        if (Schema::hasColumn('networks','lower_name')) {
            Schema::table('networks', function (Blueprint $table) {
                $table->dropIndex(['lower_name']);
                $table->dropColumn('lower_name');
            });
        }
    }
};
