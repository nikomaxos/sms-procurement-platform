<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasColumn('dropdown_items', 'position')) {
            Schema::table('dropdown_items', function (Blueprint $table) {
                $table->integer('position')->default(0)->index();
            });
            // Backfill existing rows with sequential positions per menu
            $pos = [];
            foreach (DB::table('dropdown_items')->orderBy('dropdown_menu_id')->orderBy('id')->cursor() as $row) {
                $m = $row->dropdown_menu_id;
                $pos[$m] = ($pos[$m] ?? 0) + 1;
                DB::table('dropdown_items')->where('id', $row->id)->update(['position' => $pos[$m]]);
            }
        }
    }
    public function down(): void {
        if (Schema::hasColumn('dropdown_items', 'position')) {
            Schema::table('dropdown_items', function (Blueprint $table) {
                $table->dropColumn('position');
            });
        }
    }
};
