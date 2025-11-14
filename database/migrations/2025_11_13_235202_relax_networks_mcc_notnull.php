<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc DROP NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mnc DROP NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc_mnc DROP NOT NULL"); } catch (\Throwable $e) {}
    }
    public function down(): void {
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc SET NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mnc SET NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc_mnc SET NOT NULL"); } catch (\Throwable $e) {}
    }
};
