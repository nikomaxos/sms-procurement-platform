#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

echo "==> 1) Patch the failing migration to be index-safe & idempotent"
mig="$(ls -1 database/migrations/*_add_network_mncs_and_audit.php 2>/dev/null | tail -n1)"
if [ -z "$mig" ]; then
  echo "No existing *_add_network_mncs_and_audit.php found; creating a fresh one."
  ts="$(date +%Y_%m_%d_%H%M%S)"
  mig="database/migrations/${ts}_add_network_mncs_and_audit.php"
fi

cat > "$mig" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        // 1) Create table if missing; otherwise only add missing columns/indexes.
        if (!Schema::hasTable('network_mncs')) {
            Schema::create('network_mncs', function (Blueprint $t) {
                $t->id();
                $t->foreignId('network_id')->constrained('networks')->onDelete('cascade');
                $t->string('mcc', 6);
                $t->string('mnc', 6);
                $t->string('mcc_mnc', 12)->index();
                $t->boolean('marked_for_deletion')->default(false)->index();
                $t->foreignId('created_by_user_id')->nullable()->constrained('users')->nullOnDelete();
                $t->foreignId('updated_by_user_id')->nullable()->constrained('users')->nullOnDelete();
                $t->string('created_by_source')->nullable();
                $t->string('updated_by_source')->nullable();
                $t->timestamps();
                // Single necessary uniqueness: (mcc,mnc)
                $t->unique(['mcc','mnc'],'nx_network_mncs_mcc_mnc');
            });
            // Optional fast lookup: unique(mcc_mnc) but guard name collisions.
            DB::statement("CREATE UNIQUE INDEX IF NOT EXISTS nx_network_mncs_mccmnc ON network_mncs (mcc_mnc)");
        } else {
            Schema::table('network_mncs', function (Blueprint $t) {
                if (!Schema::hasColumn('network_mncs','network_id')) {
                    $t->foreignId('network_id')->constrained('networks')->onDelete('cascade');
                }
                foreach (['mcc'=>6,'mnc'=>6,'mcc_mnc'=>12] as $col=>$len) {
                    if (!Schema::hasColumn('network_mncs',$col)) $t->string($col, $len)->nullable();
                }
                if (!Schema::hasColumn('network_mncs','marked_for_deletion')) $t->boolean('marked_for_deletion')->default(false)->index();
                if (!Schema::hasColumn('network_mncs','created_by_user_id')) $t->foreignId('created_by_user_id')->nullable()->constrained('users')->nullOnDelete();
                if (!Schema::hasColumn('network_mncs','updated_by_user_id')) $t->foreignId('updated_by_user_id')->nullable()->constrained('users')->nullOnDelete();
                if (!Schema::hasColumn('network_mncs','created_by_source')) $t->string('created_by_source')->nullable();
                if (!Schema::hasColumn('network_mncs','updated_by_source')) $t->string('updated_by_source')->nullable();
                if (!Schema::hasColumn('network_mncs','created_at')) $t->timestamps();
            });
            // Ensure indexes exist without clashing with previous names
            DB::statement("CREATE UNIQUE INDEX IF NOT EXISTS nx_network_mncs_mcc_mnc ON network_mncs (mcc, mnc)");
            DB::statement("CREATE INDEX IF NOT EXISTS ix_network_mncs_mcc_mnc_flags ON network_mncs (mcc, mnc, marked_for_deletion)");
            DB::statement("CREATE UNIQUE INDEX IF NOT EXISTS nx_network_mncs_mccmnc ON network_mncs (mcc_mnc)");
        }

        // 2) Add audit columns on networks if missing
        Schema::table('networks', function (Blueprint $t) {
            if (!Schema::hasColumn('networks','created_by_user_id')) $t->foreignId('created_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            if (!Schema::hasColumn('networks','updated_by_user_id')) $t->foreignId('updated_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            if (!Schema::hasColumn('networks','created_by_source')) $t->string('created_by_source')->nullable();
            if (!Schema::hasColumn('networks','updated_by_source')) $t->string('updated_by_source')->nullable();
        });

        // 3) Create a unique key on (country_id, lower(name)) to keep one Network per country/name
        DB::statement("CREATE UNIQUE INDEX IF NOT EXISTS uniq_networks_country_lowername ON networks (country_id, lower(name))");
    }

    public function down(): void {
        // Non-destructive down (keep data)
        if (Schema::hasTable('network_mncs')) {
            // leave table/data intact by design
        }
        // Drop unique index if present
        try { DB::statement("DROP INDEX IF EXISTS uniq_networks_country_lowername"); } catch (\Throwable $e) {}
    }
};
PHP

echo "==> 2) Add a merge command that consolidates duplicate Networks by (country_id, lower(name))"
mkdir -p app/Console/Commands
cat > app/Console/Commands/MergeNetworksByCountryName.php <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class MergeNetworksByCountryName extends Command {
    protected $signature = 'networks:merge-country-name';
    protected $description = 'Merge duplicate networks per (country_id, lower(name)) and re-home MNCs.';

    public function handle(): int {
        $this->info("Scanning duplicates…");
        $dups = DB::table('networks')
            ->select('country_id', DB::raw('lower(name) as lname'), DB::raw('array_agg(id order by id) as ids'))
            ->groupBy('country_id', DB::raw('lower(name)'))
            ->havingRaw('count(*) > 1')
            ->get();

        foreach ($dups as $d) {
            $ids = $d->ids;
            if (!is_array($ids)) $ids = json_decode(str_replace(['{','}'],['[',']'],$ids), true) ?: [];
            if (count($ids) < 2) continue;
            $keep = array_shift($ids);
            $this->info("Merging into #$keep from: ".implode(',', $ids));
            // Re-home MNCs
            DB::table('network_mncs')->whereIn('network_id', $ids)->update(['network_id'=>$keep]);
            // Delete empties
            DB::table('networks')->whereIn('id', $ids)->delete();
        }

        // Enforce unique index (safe if already exists)
        DB::statement("CREATE UNIQUE INDEX IF NOT EXISTS uniq_networks_country_lowername ON networks (country_id, lower(name))");
        $this->info("Done.");
        return 0;
    }
}
PHP

echo "==> 3) Ensure the command is registered in Console Kernel"
php -r '
$kf="app/Console/Kernel.php";
if(!file_exists($kf)){
    @mkdir("app/Console",0777,true);
    file_put_contents($kf,"<?php\nnamespace App\\Console;\nuse Illuminate\\Console\\Scheduling\\Schedule;\nuse Illuminate\\Foundation\\Console\\Kernel as ConsoleKernel;\nclass Kernel extends ConsoleKernel{protected function schedule(Schedule $s):void{} protected function commands():void{require base_path(\"routes/console.php\");}}\n");
}
$s=file_get_contents($kf);
if(strpos($s,"MergeNetworksByCountryName::class")===false){
  $s=preg_replace("/class\\s+Kernel\\s+extends\\s+ConsoleKernel\\s*\\{/",
    "use App\\\\Console\\\\Commands\\\\MergeNetworksByCountryName;\n\nclass Kernel extends ConsoleKernel {",
    $s,1);
  $s=preg_replace("/protected\\s+function\\s+commands\\(\\)\\s*:\\s*void\\s*\\{/",
    "protected function commands(): void {\n        \$this->commands([\n            MergeNetworksByCountryName::class,\n        ]);\n",
    $s,1);
  file_put_contents($kf,$s);
}
'

echo "==> 4) Migrate (idempotent)"
$DC exec -T app sh -lc 'php artisan migrate --force'

echo "==> 5) Merge duplicates and enforce unique key"
$DC exec -T app sh -lc 'php artisan networks:merge-country-name'

echo "==> 6) Rebuild caches"
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "==> 7) Fix storage perms (safety)"
$DC exec -T app sh -lc 'install -d -m 0777 storage/framework/{cache,sessions,views} bootstrap/cache && chmod -R 0777 storage bootstrap/cache'

echo "All set. If you previously ran an import, you can re-run it now to reconcile."
