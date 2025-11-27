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

            // Link to the live offer (no DB-level FK, to avoid dependency on table types)
            $table->unsignedBigInteger('supplier_offer_id')->nullable()->index();

            $table->unsignedBigInteger('country_id')->nullable()->index();
            $table->unsignedBigInteger('network_id')->nullable()->index();
            $table->unsignedBigInteger('network_mnc_id')->nullable()->index();

            $table->unsignedBigInteger('supplier_id')->nullable()->index();
            $table->unsignedBigInteger('supplier_connection_id')->nullable()->index();

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

            // When this historic row was recorded into the history
            $table->timestamp('recorded_at')->useCurrent();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offer_history');
    }
};
