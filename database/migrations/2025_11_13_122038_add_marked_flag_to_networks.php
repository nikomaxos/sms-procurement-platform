<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasColumn('networks','marked_for_deletion')) {
            Schema::table('networks', function (Blueprint $t) {
                $t->boolean('marked_for_deletion')->default(false)->index();
            });
        }
    }
    public function down(): void { /* keep */ }
};
