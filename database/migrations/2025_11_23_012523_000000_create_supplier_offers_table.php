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

            // Dimensional keys (no FKs to views)
            $table->unsignedBigInteger('country_id')->nullable()->index();
            $table->unsignedBigInteger('network_id')->nullable()->index();
            $table->unsignedBigInteger('network_mnc_id')->nullable()->index();

            // Supplier / connection (real tables – keep FKs)
            $table->foreignId('supplier_id')->constrained('suppliers')->cascadeOnDelete();
            $table->foreignId('supplier_connection_id')->constrained('supplier_connections')->cascadeOnDelete();

            // Commercial info
            $table->decimal('price', 12, 6);
            $table->string('mcc', 3)->nullable();
            $table->string('mnc', 3)->nullable();
            $table->string('mcc_mnc', 6)->nullable()->index();

            // Product Type, Known Hops, Sender Id Supported -> dropdown_items
            $table->unsignedBigInteger('product_type_id')->nullable()->index();
            $table->unsignedBigInteger('known_hops_dropdown_item_id')->nullable()->index();
            $table->unsignedBigInteger('sender_id_supported_dropdown_item_id')->nullable()->index();

            // Route & Charge model
            $table->unsignedBigInteger('route_type_id')->nullable()->index();
            $table->unsignedBigInteger('charge_model_id')->nullable()->index();

            // Charge type (Per Submit / Per Delivered)
            $table->string('charge_type', 32)->nullable();

            // Exclusivity
            $table->boolean('is_exclusive')->default(false);

            // Effective date (when this price became active)
            $table->timestamp('effective_date')->nullable()->index();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offers');
    }
};
