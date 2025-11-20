#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
LOG="logs/step1f_$ts.log"; mkdir -p logs
exec > >(tee -a "$LOG") 2>&1
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Step1f: dedupe (mcc,mnc) + upsert, and populate country_mccs"

# 1) Patch the importer service
F=app/Services/CarrierImportService.php
mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use App\Models\Country;
use App\Models\Network;

class CarrierImportService {
    /**
     * Import MCC/MNC dataset into countries, networks, country_mccs, network_mncs.
     * Dedupe per (mcc,mnc) to satisfy unique index and use upserts.
     *
     * @return array{ok:bool,msg:string,createdCountries:int,createdNetworks:int,createdMncs:int}
     */
    public function import(string $source = 'itu', bool $fresh = false): array {
        $createdCountries = 0; $createdNetworks = 0; $createdMncs = 0;

        if ($fresh) {
            DB::table('network_mncs')->truncate();
            DB::table('country_mccs')->truncate();
        }

        // Pull remote, fall back to bundled file if present
        $urls = [
            'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
            resource_path('data/mcc-mnc-table.json'),
        ];

        $rows = [];
        foreach ($urls as $url) {
            try {
                if (str_starts_with($url, 'http')) {
                    $res = Http::timeout(30)->get($url);
                    if ($res->successful()) {
                        $data = $res->json();
                        if (is_array($data)) $rows = array_merge($rows, $data);
                    }
                } else {
                    if (is_file($url)) {
                        $data = json_decode(file_get_contents($url), true);
                        if (is_array($data)) $rows = array_merge($rows, $data);
                    }
                }
            } catch (\Throwable $e) {
                // ignore and try next
            }
        }

        if (!$rows) {
            return ['ok'=>false,'msg'=>'No data fetched','createdCountries'=>0,'createdNetworks'=>0,'createdMncs'=>0];
        }

        // Deduplicate per (mcc,mnc)
        $seen = [];

        DB::transaction(function () use ($rows, &$createdCountries, &$createdNetworks, &$createdMncs, &$seen) {
            foreach ($rows as $r) {
                $mcc = trim((string)($r['mcc'] ?? $r['MCC'] ?? ''));
                $mnc = trim((string)($r['mnc'] ?? $r['MNC'] ?? ''));
                $cname = trim((string)($r['country'] ?? $r['country_name'] ?? $r['countryName'] ?? ''));
                $iso2  = strtolower(trim((string)($r['iso'] ?? $r['iso2'] ?? $r['country_code'] ?? '')));
                $netName = trim((string)($r['brand'] ?? $r['operator'] ?? $r['network'] ?? ''));

                if ($mcc === '' || $mnc === '' || $cname === '' || $netName === '') {
                    continue;
                }

                $key = $mcc.'-'.$mnc;
                if (isset($seen[$key])) {
                    // already processed this MCC/MNC combination
                    continue;
                }
                $seen[$key] = true;

                // Country (match case-insensitively on name)
                $country = Country::whereRaw('LOWER(name) = ?', [mb_strtolower($cname)])->first();
                if (!$country) {
                    $country = Country::create(['name' => $cname, 'iso2' => $iso2 ?: null]);
                    $createdCountries++;
                }

                // Network in that country by lower(name)
                $lname = mb_strtolower($netName);
                $network = Network::where('country_id', $country->id)
                    ->whereRaw('LOWER(name) = ?', [$lname])
                    ->first();
                if (!$network) {
                    // keep lower_name in sync if the column exists
                    $attrs = ['country_id' => $country->id, 'name' => $netName];
                    if (schema_has_column('networks', 'lower_name')) {
                        $attrs['lower_name'] = $lname;
                    }
                    $network = Network::create($attrs);
                    $createdNetworks++;
                }

                // country_mccs upsert (unique per (country_id,mcc))
                $mccInt = (int)$mcc;
                $exCountryMcc = DB::table('country_mccs')
                    ->where('country_id', $country->id)->where('mcc', $mccInt)->exists();

                DB::table('country_mccs')->updateOrInsert(
                    ['country_id' => $country->id, 'mcc' => $mccInt],
                    ['updated_at' => now(), 'created_at' => now()]
                );

                // network_mncs upsert (unique per (mcc,mnc) by DB constraint)
                $mncInt = (int)$mnc;
                $existsMnc = DB::table('network_mncs')
                    ->where('mcc', $mccInt)->where('mnc', $mncInt)->exists();

                DB::table('network_mncs')->updateOrInsert(
                    ['mcc' => $mccInt, 'mnc' => $mncInt],
                    [
                        'network_id' => $network->id,
                        // store as integer if column is integer, DB will coerce from string too
                        'mcc_mnc' => (int)($mcc.$mnc),
                        'updated_at' => now(),
                        'created_at' => now()
                    ]
                );

                if (!$existsMnc) {
                    $createdMncs++;
                }
            }
        });

        return [
            'ok' => true,
            'msg' => 'Import complete',
            'createdCountries' => $createdCountries,
            'createdNetworks' => $createdNetworks,
            'createdMncs' => $createdMncs
        ];
    }
}

/**
 * Tiny helper to avoid calling Schema facade in service without booted app.
 * We check information_schema instead; works in all supported DBs.
 */
if (!function_exists('schema_has_column')) {
    function schema_has_column(string $table, string $column): bool {
        try {
            $db = DB::getConfig('database') ?: DB::getDatabaseName();
            $res = DB::select(
                'select 1 from information_schema.columns where table_name = ? and column_name = ?',
                [$table, $column]
            );
            return !empty($res);
        } catch (\Throwable $e) {
            return false;
        }
    }
}
PHP

# 2) Rebuild autoload & clear caches
$DC exec -T app sh -lc '
  php -l app/Services/CarrierImportService.php
  php artisan optimize:clear
  php artisan config:clear
  php artisan route:clear
  php artisan view:clear
  php artisan cache:clear
  composer dump-autoload -o
'

# 3) Diagnostics helper (safe bootstrap)
run_php () {
  local BODY="$1"
  $DC exec -T app sh -lc 'cat > /tmp/run_once.php <<'\''PHP'\'' 
<?php
require __DIR__."/vendor/autoload.php";
$app = require __DIR__."/bootstrap/app.php";
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();
'$(printf "%s" "$BODY")'
PHP
php /tmp/run_once.php; rm -f /tmp/run_once.php'
}

echo "==> BEFORE counts"
run_php '
use Illuminate\Support\Facades\DB;
echo json_encode([
  "countries"=>DB::table("countries")->count(),
  "country_mccs"=>DB::table("country_mccs")->count(),
  "networks"=>DB::table("networks")->count(),
  "network_mncs"=>DB::table("network_mncs")->count(),
], JSON_PRETTY_PRINT), PHP_EOL;'

echo "==> Run importer (fresh)"
$DC exec -T app sh -lc "php artisan carriers:import --fresh -v || true"

echo "==> AFTER counts"
run_php '
use Illuminate\Support\Facades\DB;
echo json_encode([
  "countries"=>DB::table("countries")->count(),
  "country_mccs"=>DB::table("country_mccs")->count(),
  "networks"=>DB::table("networks")->count(),
  "network_mncs"=>DB::table("network_mncs")->count(),
], JSON_PRETTY_PRINT), PHP_EOL;'

echo "==> Sample links (country_mccs & network_mncs)"
run_php '
use Illuminate\Support\Facades\DB;
$out = [
  "country_mccs" => DB::table("country_mccs")->orderBy("country_id")->limit(5)->get(),
  "network_mncs" => DB::table("network_mncs")->orderBy("mcc")->orderBy("mnc")->limit(5)->get(),
];
echo json_encode($out, JSON_PRETTY_PRINT), PHP_EOL;'

echo "==> Done. Log: $LOG"
