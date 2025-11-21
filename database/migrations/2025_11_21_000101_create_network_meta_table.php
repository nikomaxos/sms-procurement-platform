<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('network_meta')) {
            Schema::create('network_meta', function (Blueprint $table): void {
                $table->id();
                // networks.id is bigint; avoid FK because networks is a view.
                $table->unsignedBigInteger('network_id')->unique();
                $table->boolean('non_operational')->default(false)->index();
                $table->text('notes')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('network_meta')) {
            Schema::drop('network_meta');
        }
    }
};
