<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Providers / Suppliers Updates
        if (Schema::hasTable('suppliers')) {
            Schema::table('suppliers', function (Blueprint $table) {
                if (!Schema::hasColumn('suppliers', 'status')) {
                    $table->string('status')->default('active')->index()->after('notes')->comment('active, suspended');
                }
            });
        }

        if (Schema::hasTable('supplier_connections')) {
            Schema::table('supplier_connections', function (Blueprint $table) {
                if (!Schema::hasColumn('supplier_connections', 'connection_type')) {
                    $table->string('connection_type')->default('rest')->after('username')->comment('smpp, rest');
                }
                if (!Schema::hasColumn('supplier_connections', 'api_credentials')) {
                    $table->json('api_credentials')->nullable()->after('connection_type');
                }
            });
        }

        // 2. Destinations / Countries Updates
        if (Schema::hasTable('countries')) {
            Schema::table('countries', function (Blueprint $table) {
                if (!Schema::hasColumn('countries', 'prefix')) {
                    $table->string('prefix', 10)->nullable()->index()->after('iso2');
                }
            });
        }

        // 3. Vendor Rates / Supplier Offers Updates
        if (Schema::hasTable('supplier_offers')) {
            Schema::table('supplier_offers', function (Blueprint $table) {
                if (!Schema::hasColumn('supplier_offers', 'currency')) {
                    $table->char('currency', 3)->default('EUR')->after('price');
                }
            });
        }

        // 4. Customers
        if (!Schema::hasTable('customers')) {
            Schema::create('customers', function (Blueprint $table) {
                $table->id();
                $table->string('name');
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        // 5. Customer Prices
        if (!Schema::hasTable('customer_prices')) {
            Schema::create('customer_prices', function (Blueprint $table) {
                $table->id();
                $table->foreignId('customer_id')->constrained('customers')->cascadeOnDelete();
                $table->string('mcc', 3);
                $table->string('mnc', 3)->nullable();
                $table->decimal('price', 12, 6);
                $table->char('currency', 3)->default('EUR');
                $table->timestamp('effective_date')->useCurrent();
                $table->timestamps();

                $table->index(['mcc', 'mnc']);
                $table->index('effective_date');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_prices');
        Schema::dropIfExists('customers');
        
        if (Schema::hasTable('supplier_offers')) {
            Schema::table('supplier_offers', function (Blueprint $table) {
                if (Schema::hasColumn('supplier_offers', 'currency')) {
                    $table->dropColumn('currency');
                }
            });
        }
        if (Schema::hasTable('countries')) {
            Schema::table('countries', function (Blueprint $table) {
                if (Schema::hasColumn('countries', 'prefix')) {
                    $table->dropColumn('prefix');
                }
            });
        }
        if (Schema::hasTable('supplier_connections')) {
            Schema::table('supplier_connections', function (Blueprint $table) {
                $table->dropColumn(['connection_type', 'api_credentials']);
            });
        }
        if (Schema::hasTable('suppliers')) {
            Schema::table('suppliers', function (Blueprint $table) {
                $table->dropColumn('status');
            });
        }
    }
};
