<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        // Postgres-safe idempotent unique indexes
        DB::statement('CREATE UNIQUE INDEX IF NOT EXISTS country_mccs_country_mcc_unique ON country_mccs(country_id, mcc)');
        DB::statement('CREATE UNIQUE INDEX IF NOT EXISTS network_mncs_network_mnc_unique ON network_mncs(network_id, mnc, mcc)');
    }
    public function down(): void {
        DB::statement('DROP INDEX IF EXISTS country_mccs_country_mcc_unique');
        DB::statement('DROP INDEX IF EXISTS network_mncs_network_mnc_unique');
    }
};
