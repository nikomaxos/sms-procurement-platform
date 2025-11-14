<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasTable('network_mncs')) {
            Schema::create('network_mncs', function (Blueprint $t) {
                $t->id();
                $t->foreignId('network_id')->constrained('networks')->onDelete('cascade');
                $t->string('mcc', 6);
                $t->string('mnc', 6);
                $t->string('mcc_mnc', 12)->index();
                $t->boolean('marked_for_deletion')->default(false)->index();
                $t->foreignId('created_by_user_id')->nullable()->constrained('users')->nullOnDelete();
                $t->foreignId('updated_by_user_id')->nullable()->constrained('users')->nullOnDelete();
                $t->string('created_by_source')->nullable();
                $t->string('updated_by_source')->nullable();
                $t->timestamps();
                $t->unique(['mcc','mnc'],'nx_network_mncs_mcc_mnc');
            });
            DB::statement("CREATE UNIQUE INDEX IF NOT EXISTS nx_network_mncs_mccmnc ON network_mncs (mcc_mnc)");
        } else {
            Schema::table('network_mncs', function (Blueprint $t) {
                if (!Schema::hasColumn('network_mncs','network_id')) $t->foreignId('network_id')->constrained('networks')->onDelete('cascade');
                foreach (['mcc'=>6,'mnc'=>6,'mcc_mnc'=>12] as $col=>$len) {
                    if (!Schema::hasColumn('network_mncs',$col)) $t->string($col,$len)->nullable();
                }
                if (!Schema::hasColumn('network_mncs','marked_for_deletion')) $t->boolean('marked_for_deletion')->default(false)->index();
                if (!Schema::hasColumn('network_mncs','created_by_user_id')) $t->foreignId('created_by_user_id')->nullable()->constrained('users')->nullOnDelete();
                if (!Schema::hasColumn('network_mncs','updated_by_user_id')) $t->foreignId('updated_by_user_id')->nullable()->constrained('users')->nullOnDelete();
                if (!Schema::hasColumn('network_mncs','created_by_source')) $t->string('created_by_source')->nullable();
                if (!Schema::hasColumn('network_mncs','updated_by_source')) $t->string('updated_by_source')->nullable();
                if (!Schema::hasColumn('network_mncs','created_at')) $t->timestamps();
            });
            DB::statement("CREATE UNIQUE INDEX IF NOT EXISTS nx_network_mncs_mcc_mnc ON network_mncs (mcc, mnc)");
            DB::statement("CREATE INDEX IF NOT EXISTS ix_network_mncs_flags ON network_mncs (mcc, mnc, marked_for_deletion)");
            DB::statement("CREATE UNIQUE INDEX IF NOT EXISTS nx_network_mncs_mccmnc ON network_mncs (mcc_mnc)");
        }

        Schema::table('networks', function (Blueprint $t) {
            if (!Schema::hasColumn('networks','created_by_user_id')) $t->foreignId('created_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            if (!Schema::hasColumn('networks','updated_by_user_id')) $t->foreignId('updated_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            if (!Schema::hasColumn('networks','created_by_source')) $t->string('created_by_source')->nullable();
            if (!Schema::hasColumn('networks','updated_by_source')) $t->string('updated_by_source')->nullable();
        });

        // NOTE: do NOT create the unique index on (country_id, lower(name)) here.
        // We'll merge duplicates first, then add it in a separate migration.
    }
    public function down(): void { /* keep data */ }
};
