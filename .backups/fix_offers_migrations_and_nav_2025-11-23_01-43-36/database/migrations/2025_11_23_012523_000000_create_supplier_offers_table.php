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

            // No FK to countries because in this DB 'countries' is not a regular table.
            $table->unsignedBigInteger('country_id')->nullable()->index();

            $table->foreignId('network_id')->constrained()->cascadeOnDelete();
            $table->foreignId('network_mnc_id')->constrained('network_mncs')->cascadeOnDelete();

            $table->foreignId('supplier_id')->constrained('suppliers')->cascadeOnDelete();
            $table->foreignId('supplier_connection_id')->constrained('supplier_connections')->cascadeOnDelete();

            $table->decimal('price', 12, 6);

            $table->string('mcc', 3)->nullable();
            $table->string('mnc', 3)->nullable();
            $table->string('mcc_mnc', 6)->nullable()->index();

            // Business attributes / mappings
            // Product Type, Known Hops, Sender Id Supported come from dropdown_items
            $table->unsignedBigInteger('product_type_id')->nullable()->index();                     // dropdown_items (menu 1)
            $table->unsignedBigInteger('known_hops_dropdown_item_id')->nullable()->index();        // dropdown_items (menu 2)
            $table->unsignedBigInteger('sender_id_supported_dropdown_item_id')->nullable()->index(); // dropdown_items (menu 3)

            // Route & Charge model come from their dedicated tables
            $table->unsignedBigInteger('route_type_id')->nullable()->index();   // route_types
            $table->unsignedBigInteger('charge_model_id')->nullable()->index(); // charge_models

            // Charge type (Per Submit / Per Delivered), decoupled from connection if overridden
            $table->string('charge_type', 32)->nullable();

            $table->boolean('is_exclusive')->default(false);

            // Effective date of this price
            $table->date('effective_date')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offers');
    }
};
