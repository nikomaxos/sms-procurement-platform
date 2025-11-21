<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('country_meta')) {
            Schema::create('country_meta', function (Blueprint $table): void {
                $table->id();
                $table->unsignedBigInteger('country_id')->unique();
                $table->text('notes')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('country_meta')) {
            Schema::drop('country_meta');
        }
    }
};
