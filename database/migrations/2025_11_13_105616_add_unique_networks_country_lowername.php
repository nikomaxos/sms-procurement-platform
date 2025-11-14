<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        // Now that duplicates are merged, enforce one Network per (country, name)
        DB::statement("CREATE UNIQUE INDEX IF NOT EXISTS uniq_networks_country_lowername ON networks (country_id, lower(name))");
    }
    public function down(): void {
        try { DB::statement("DROP INDEX IF EXISTS uniq_networks_country_lowername"); } catch (\Throwable $e) {}
    }
};
