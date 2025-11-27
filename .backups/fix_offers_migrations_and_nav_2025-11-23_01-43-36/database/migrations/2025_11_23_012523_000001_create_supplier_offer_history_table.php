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

            // Same dimensional keys as main offer
            $table->unsignedBigInteger('country_id')->nullable()->index();
            $table->foreignId('network_id')->constrained()->cascadeOnDelete();
            $table->foreignId('network_mnc_id')->constrained('network_mncs')->cascadeOnDelete();

            $table->foreignId('supplier_id')->constrained('suppliers')->cascadeOnDelete();
            $table->foreignId('supplier_connection_id')->constrained('supplier_connections')->cascadeOnDelete();

            $table->decimal('price', 12, 6);

            $table->string('mcc', 3)->nullable();
            $table->string('mnc', 3)->nullable();
            $table->string('mcc_mnc', 6)->nullable()->index();

            $table->unsignedBigInteger('product_type_id')->nullable()->index();
            $table->unsignedBigInteger('known_hops_dropdown_item_id')->nullable()->index();
            $table->unsignedBigInteger('sender_id_supported_dropdown_item_id')->nullable()->index();

            $table->unsignedBigInteger('route_type_id')->nullable()->index();
            $table->unsignedBigInteger('charge_model_id')->nullable()->index();

            $table->string('charge_type', 32)->nullable();
            $table->boolean('is_exclusive')->default(false);

            $table->date('effective_date')->nullable();

            // When this historic row was recorded
            $table->timestamp('recorded_at')->useCurrent();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offer_history');
    }
};
