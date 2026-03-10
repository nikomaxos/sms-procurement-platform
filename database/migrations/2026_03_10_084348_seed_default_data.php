<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Artisan;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Artisan::call('db:seed', ['--class' => 'DropdownSeeder', '--force' => true]);
        Artisan::call('db:seed', ['--class' => 'CountriesNetworksSeeder', '--force' => true]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // No down method, data remains or gets wiped elsewhere.
    }
};
