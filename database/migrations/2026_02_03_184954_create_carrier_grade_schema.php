<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Providers Table
        if (!Schema::hasTable('providers')) {
            Schema::create('providers', function (Blueprint $table) {
                $table->id();
                $table->string('name');
                $table->enum('type', ['http', 'smpp']);
                $table->json('connection_config')->nullable();
                $table->boolean('status')->default(true); // Active/Inactive
                $table->timestamps();
            });
        }

        // 2. Networks Table (Update existing)
        if (Schema::hasTable('networks')) {
            Schema::table('networks', function (Blueprint $table) {
                if (!Schema::hasColumn('networks', 'iso')) {
                    $table->string('iso', 2)->nullable()->after('mnc');
                }
                if (!Schema::hasColumn('networks', 'country_name')) {
                    $table->string('country_name')->nullable()->after('iso');
                }
                if (!Schema::hasColumn('networks', 'network_name')) {
                    $table->string('network_name')->nullable()->after('name');
                }
                if (!Schema::hasColumn('networks', 'prefix')) {
                    $table->string('prefix')->nullable()->index()->after('network_name');
                }
                
                // Add compound index if it doesn't exist
                // Ideally check existence, but adding index via Schema builder usually handles naming.
                // We'll trust Laravel to handle or throw if duplicate (which we can catch, or just let it be).
                // Giving it a specific name avoids duplication errors if name matches auto-generated.
                $table->index(['mcc', 'mnc'], 'networks_mcc_mnc_compound_index');
            });
        } else {
            // Fallback if table somehow missing
            Schema::create('networks', function (Blueprint $table) {
                $table->id();
                $table->string('mcc', 3);
                $table->string('mnc', 3);
                $table->string('iso', 2)->nullable();
                $table->string('country_name')->nullable();
                $table->string('network_name')->nullable();
                $table->string('prefix')->nullable()->index();
                $table->timestamps();
                
                $table->index(['mcc', 'mnc'], 'networks_mcc_mnc_compound_index');
            });
        }

        // 3. Vendor Rates
        if (!Schema::hasTable('vendor_rates')) {
            Schema::create('vendor_rates', function (Blueprint $table) {
                $table->id();
                $table->foreignId('provider_id')->constrained('providers')->cascadeOnDelete();
                $table->string('mcc', 3);
                $table->string('mnc', 3);
                $table->decimal('rate', 12, 6);
                $table->string('currency', 3)->default('EUR');
                $table->dateTime('effective_date')->nullable();
                $table->timestamps();
                
                $table->index(['mcc', 'mnc']);
                $table->index('provider_id');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('vendor_rates');
        Schema::dropIfExists('providers');
        
        if (Schema::hasTable('networks')) {
            Schema::table('networks', function (Blueprint $table) {
                $table->dropColumn(['iso', 'country_name', 'network_name', 'prefix']);
                $table->dropIndex('networks_mcc_mnc_compound_index');
            });
        }
    }
};
