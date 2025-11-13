<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
  public function up(): void {
    if (!Schema::hasTable('countries')) {
      Schema::create('countries', function (Blueprint $t) {
        $t->id();
        $t->string('name', 120);
        $t->string('iso2', 2)->nullable()->index();
        $t->timestamps();
      });
    }
    if (!Schema::hasTable('country_mccs')) {
      Schema::create('country_mccs', function (Blueprint $t) {
        $t->id();
        $t->foreignId('country_id')->constrained('countries')->cascadeOnDelete();
        $t->string('mcc', 3)->index();
        $t->timestamps();
        $t->unique(['mcc']);
      });
    }
    if (!Schema::hasTable('networks')) {
      Schema::create('networks', function (Blueprint $t) {
        $t->id();
        $t->string('name', 160);
        $t->string('mcc', 3)->index();
        $t->string('mnc', 3)->index();
        $t->string('mcc_mnc', 6)->unique();
        $t->foreignId('country_id')->nullable()->constrained('countries')->nullOnDelete()->index();
        $t->timestamps();
      });
    }
  }
  public function down(): void {
    Schema::dropIfExists('networks');
    Schema::dropIfExists('country_mccs');
    Schema::dropIfExists('countries');
  }
};
