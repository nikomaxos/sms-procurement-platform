<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('supplier_offer_history', function (Blueprint $table) {
            $table->id();

            $table->foreignId('supplier_offer_id')
                ->constrained('supplier_offers')
                ->cascadeOnDelete();

            $table->foreignId('supplier_id')->constrained('suppliers')->cascadeOnDelete();
            $table->foreignId('supplier_connection_id')->constrained('supplier_connections')->cascadeOnDelete();
            $table->foreignId('country_id')->constrained()->cascadeOnDelete();
            $table->foreignId('network_id')->constrained()->cascadeOnDelete();
            $table->foreignId('network_mnc_id')->constrained('network_mncs')->cascadeOnDelete();

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

            $table->date('effective_date');

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offer_history');
    }
};
