#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
LOG="logs/step1d_$ts.log"; mkdir -p logs
exec > >(tee -a "$LOG") 2>&1

echo "==> Step1d: add networks.lower_name (if missing) + make importer schema-aware"

############################################
# 1) Overwrite CarrierImportService to be schema-aware
############################################
F=app/Services/CarrierImportService.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use App\Models\Country;
use App\Models\Network;

class CarrierImportService {
    /**
     * @return array{ok:bool,msg:string,createdCountries:int,createdNetworks:int,createdMncs:int}
     */
    public function import(string $source, bool $fresh): array {
        $createdCountries=0; $createdNetworks=0; $createdMncs=0;

        if ($fresh) {
            DB::table('network_mncs')->truncate();
            DB::table('country_mccs')->truncate();
        }

        $urls = [
            'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
            'https://raw.githubusercontent.com/onnimonni/mcc-mnc-list/master/mcc-mnc-list.json',
        ];

        $rows = [];
        foreach ($urls as $url) {
            try {
                $res = Http::timeout(30)->get($url);
                if ($res->successful()) {
                    $data = $res->json();
                    if (is_array($data)) { $rows = array_merge($rows, $data); }
                }
            } catch (\Throwable $e) {}
            if (!empty($rows)) break;
        }

        if (empty($rows)) {
            $local = base_path('resources/data/mcc-mnc-table.json');
            if (is_file($local)) {
                try { $data = json_decode(file_get_contents($local), true); if (is_array($data)) { $rows = $data; } } catch (\Throwable $e) {}
            }
        }

        if (empty($rows)) {
            return ['ok'=>false,'msg'=>'No data fetched (remote) and no local fallback','createdCountries'=>0,'createdNetworks'=>0,'createdMncs'=>0];
        }

        $hasLower = Schema::hasColumn('networks','lower_name');

        DB::transaction(function () use ($rows, &$createdCountries, &$createdNetworks, &$createdMncs, $hasLower) {
            foreach ($rows as $r) {
                $mcc     = trim((string)($r['mcc'] ?? $r['MCC'] ?? ''));
                $mnc     = trim((string)($r['mnc'] ?? $r['MNC'] ?? ''));
                $cname   = trim((string)($r['country'] ?? $r['country_name'] ?? $r['countryName'] ?? ''));
                $iso2    = strtolower(trim((string)($r['iso'] ?? $r['iso2'] ?? $r['country_code'] ?? '')));
                $netName = trim((string)($r['brand'] ?? $r['operator'] ?? $r['network'] ?? ''));

                if ($mcc === '' || $mnc === '' || $cname === '' || $netName === '') continue;

                $country = Country::firstOrCreate(['name' => $cname], ['iso2' => $iso2 ?: null]);
                if ($country->wasRecentlyCreated) $createdCountries++;

                $lower = mb_strtolower($netName);

                if ($hasLower) {
                    $network = Network::where('country_id', $country->id)->where('lower_name', $lower)->first();
                } else {
                    $network = Network::where('country_id', $country->id)->whereRaw('LOWER(name) = ?', [$lower])->first();
                }

                if (!$network) {
                    $data = [
                        'country_id' => $country->id,
                        'name'       => $netName,
                        'marked'     => false,
                    ];
                    if ($hasLower) { $data['lower_name'] = $lower; }
                    $network = Network::create($data);
                    $createdNetworks++;
                } else {
                    $changed = false;
                    if ($network->name !== $netName) { $network->name = $netName; $changed = true; }
                    if ($hasLower && ($network->lower_name ?? null) !== $lower) { $network->lower_name = $lower; $changed = true; }
                    if ($changed) $network->save();
                }

                if (!DB::table('country_mccs')->where(['country_id'=>$country->id,'mcc'=>$mcc])->exists()) {
                    DB::table('country_mccs')->insert([
                        'country_id'=>$country->id, 'mcc'=>$mcc,
                        'created_at'=>now(), 'updated_at'=>now()
                    ]);
                }

                if (!DB::table('network_mncs')->where(['network_id'=>$network->id,'mcc'=>$mcc,'mnc'=>$mnc])->exists()) {
                    DB::table('network_mncs')->insert([
                        'network_id'=>$network->id, 'mcc'=>$mcc, 'mnc'=>$mnc,
                        'mcc_mnc'=>$mcc.$mnc, 'created_at'=>now(), 'updated_at'=>now()
                    ]);
                    $createdMncs++;
                }
            }
        });

        return ['ok'=>true,'msg'=>'done','createdCountries'=>$createdCountries,'createdNetworks'=>$createdNetworks,'createdMncs'=>$createdMncs];
    }
}
PHP

############################################
# 2) Create idempotent migration: add lower_name if missing + backfill
############################################
M="database/migrations/2025_11_14_000210_add_lower_name_to_networks.php"
if [ ! -f "$M" ]; then
  cat > "$M" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasColumn('networks','lower_name')) {
            Schema::table('networks', function (Blueprint $table) {
                $table->string('lower_name')->nullable()->index();
            });
            // Backfill
            DB::statement('UPDATE networks SET lower_name = LOWER(name) WHERE lower_name IS NULL');
            // (Index is already added above; avoid unique to prevent failures on legacy dupes)
        } else {
            // Ensure any nulls are backfilled
            DB::statement('UPDATE networks SET lower_name = LOWER(name) WHERE lower_name IS NULL');
        }
    }
    public function down(): void {
        if (Schema::hasColumn('networks','lower_name')) {
            Schema::table('networks', function (Blueprint $table) {
                $table->dropIndex(['lower_name']);
                $table->dropColumn('lower_name');
            });
        }
    }
};
PHP
fi

############################################
# 3) Autoload, migrate, run fresh import, show counts
############################################
$DC exec -T app sh -lc '
  php -l app/Services/CarrierImportService.php
  composer dump-autoload -o
  php artisan migrate --force
  php artisan carriers:import --fresh -v
  php artisan tinker --execute "echo json_encode([
    \"countries\"=>DB::table(\"countries\")->count(),
    \"country_mccs\"=>DB::table(\"country_mccs\")->count(),
    \"networks\"=>DB::table(\"networks\")->count(),
    \"network_mncs\"=>DB::table(\"network_mncs\")->count()
  ], JSON_PRETTY_PRINT);"
'
echo "==> Step1d complete. Log: $LOG"
