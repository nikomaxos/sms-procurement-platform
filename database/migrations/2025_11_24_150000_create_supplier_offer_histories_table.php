<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::hasTable('supplier_offer_histories')) {
            return;
        }

        Schema::create('supplier_offer_histories', function (Blueprint $table) {
            $table->bigIncrements('id');

            // Foreign keys (χωρίς constraints για να μην σπάει τίποτα)
            $table->unsignedBigInteger('supplier_offer_id')->index();
            $table->unsignedBigInteger('supplier_id')->nullable()->index();
            $table->unsignedBigInteger('supplier_connection_id')->nullable()->index();
            $table->unsignedBigInteger('country_id')->nullable()->index();
            $table->unsignedBigInteger('network_id')->nullable()->index();
            $table->unsignedBigInteger('network_mnc_id')->nullable()->index();

            // Price όπως στο supplier_offers (decimal με 6 δεκαδικά)
            $table->decimal('price', 15, 6)->nullable();

            // MCC / MNC / MCCMNC
            $table->string('mcc', 8)->nullable();
            $table->string('mnc', 8)->nullable();
            $table->string('mcc_mnc', 16)->nullable();

            // Business fields όπως τα γράφει τώρα ο controller στο insert
            $table->string('product_type', 100)->nullable();
            $table->string('known_hops', 255)->nullable();
            $table->string('sender_id_supported', 255)->nullable();

            $table->string('charge_type', 100)->nullable();
            $table->boolean('is_exclusive')->default(false);

            // route_type υπάρχει ακόμη στο insert, το κρατάμε nullable
            $table->string('route_type', 100)->nullable();

            $table->date('effective_date')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_offer_histories');
    }
};
