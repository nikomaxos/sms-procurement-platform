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

            // NOTE: All foreign keys are plain unsignedBigInteger + index
            // to avoid FK issues with views/materialized relations.
            $table->unsignedBigInteger('country_id')->nullable()->index();
            $table->unsignedBigInteger('network_id')->nullable()->index();
            $table->unsignedBigInteger('network_mnc_id')->nullable()->index();

            $table->unsignedBigInteger('supplier_id')->nullable()->index();
            $table->unsignedBigInteger('supplier_connection_id')->nullable()->index();

            $table->decimal('price', 12, 6);

            $table->string('mcc', 3)->nullable();
            $table->string('mnc', 3)->nullable();
            $table->string('mcc_mnc', 6)->nullable()->index();

            // Product type and other dropdown-driven attributes
            $table->unsignedBigInteger('product_type_id')->nullable()->index();                     // dropdown_items (menu 1)
            $table->unsignedBigInteger('known_hops_dropdown_item_id')->nullable()->index();        // dropdown_items (menu 2)
            $table->unsignedBigInteger('sender_id_supported_dropdown_item_id')->nullable()->index(); // dropdown_items (menu 3)

            // Route & charge model mappings
            $table->unsignedBigInteger('route_type_id')->nullable()->index();   // route_types
            $table->unsignedBigInteger('charge_model_id')->nullable()->index(); // charge_models

            // Charge type (Per Submit / Per Delivered) – maybe overridden vs connection
            $table->string('charge_type', 32)->nullable();

            $table->boolean('is_exclusive')->default(false);

            // Effective date of this price (business date, not created_at)
            $table->date('effective_date')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offers');
    }
};
