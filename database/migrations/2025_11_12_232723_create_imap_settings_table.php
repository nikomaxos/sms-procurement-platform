<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasTable('imap_settings')) {
            Schema::create('imap_settings', function (Blueprint $table) {
                $table->id();
                $table->string('host')->nullable();
                $table->unsignedInteger('port')->nullable();
                $table->enum('encryption', ['none','ssl','tls'])->default('ssl');
                $table->string('username')->nullable();
                $table->string('password')->nullable(); // NOTE: stored as-is for now
                $table->boolean('enabled')->default(false);
                $table->unsignedInteger('poll_minutes')->default(5);
                $table->json('selected_folders')->nullable();
                $table->json('last_folders_cache')->nullable();
                $table->text('last_test_log')->nullable();
                $table->timestamps();
            });
            // seed singleton row
            DB::table('imap_settings')->insert([
                'id' => 1,
                'host' => null,
                'port' => 993,
                'encryption' => 'ssl',
                'username' => null,
                'password' => null,
                'enabled' => false,
                'poll_minutes' => 5,
                'selected_folders' => json_encode([]),
                'last_folders_cache' => json_encode([]),
                'last_test_log' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        } else {
            // Add any missing columns if table already exists
            Schema::table('imap_settings', function (Blueprint $table) {
                if (!Schema::hasColumn('imap_settings','encryption')) $table->enum('encryption',['none','ssl','tls'])->default('ssl');
                if (!Schema::hasColumn('imap_settings','enabled')) $table->boolean('enabled')->default(false);
                if (!Schema::hasColumn('imap_settings','poll_minutes')) $table->unsignedInteger('poll_minutes')->default(5);
                if (!Schema::hasColumn('imap_settings','selected_folders')) $table->json('selected_folders')->nullable();
                if (!Schema::hasColumn('imap_settings','last_folders_cache')) $table->json('last_folders_cache')->nullable();
                if (!Schema::hasColumn('imap_settings','last_test_log')) $table->text('last_test_log')->nullable();
            });
        }
    }

    public function down(): void {
        Schema::dropIfExists('imap_settings');
    }
};
