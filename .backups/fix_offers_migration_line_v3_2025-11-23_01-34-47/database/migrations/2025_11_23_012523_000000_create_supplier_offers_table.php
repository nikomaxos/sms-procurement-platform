<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('supplier_offers', function (Blueprint $table) {
            $table->id();

            ->foreignId('country_id')->nullable()->index();
            $table->foreignId('network_id')->constrained()->cascadeOnDelete();
            $table->foreignId('network_mnc_id')->constrained('network_mncs')->cascadeOnDelete();

            $table->foreignId('supplier_id')->constrained('suppliers')->cascadeOnDelete();
            $table->foreignId('supplier_connection_id')->constrained('supplier_connections')->cascadeOnDelete();

            $table->decimal('price', 12, 6);

            $table->string('mcc', 3)->nullable();
            $table->string('mnc', 3)->nullable();
            $table->string('mcc_mnc', 6)->nullable()->index();

            $table->string('product_type')->nullable();
            $table->string('known_hops')->nullable();
            $table->string('sender_id_supported')->nullable();
            $table->string('charge_type', 32)->nullable();

            $table->boolean('is_exclusive')->default(false);
            $table->string('route_type')->nullable();

            // Effective date of this price/version
            $table->date('effective_date');

            $table->timestamps();

            // Only one "live" offer per supplier_connection + network_mnc
            $table->unique(
                ['supplier_connection_id', 'network_mnc_id'],
                'supplier_offers_conn_mnc_unique'
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offers');
    }
};
