<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('country_mccs', function (Blueprint $table) {
            if (!Schema::hasColumn('country_mccs', 'marked_for_deletion')) {
                $table->boolean('marked_for_deletion')->default(false);
            }
            if (!Schema::hasColumn('country_mccs', 'created_by_user_id')) {
                $table->unsignedBigInteger('created_by_user_id')->nullable();
            }
            if (!Schema::hasColumn('country_mccs', 'updated_by_user_id')) {
                $table->unsignedBigInteger('updated_by_user_id')->nullable();
            }
            if (!Schema::hasColumn('country_mccs', 'created_by_source')) {
                $table->string('created_by_source', 64)->nullable();
            }
            if (!Schema::hasColumn('country_mccs', 'updated_by_source')) {
                $table->string('updated_by_source', 64)->nullable();
            }
        });
    }
    public function down(): void {
        Schema::table('country_mccs', function (Blueprint $table) {
            foreach (['marked_for_deletion','created_by_user_id','updated_by_user_id','created_by_source','updated_by_source'] as $col) {
                if (Schema::hasColumn('country_mccs', $col)) $table->dropColumn($col);
            }
        });
    }
};
