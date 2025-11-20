#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
LOG="logs/step1h_$ts.log"; mkdir -p logs resources/data app/Services
exec > >(tee -a "$LOG") 2>&1

echo "==> Step1h: hard-restore CarrierImportService + safe upserts, then re-run import"

F=app/Services/CarrierImportService.php
b "$F"
cat > "$F" <<'PHP'
<?php
namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use App\Models\Country;
use App\Models\Network;

/**
 * Importer for MCC/MNC data:
 * - Dedupes by (mcc,mnc)
 * - Upserts network_mncs by ['mcc','mnc'] (unique index)
 * - Upserts country_mccs by ['mcc'] (unique index)
 * - Matches Network by (country_id, lower(name))
 */
class CarrierImportService {
    /**
     * @return array{ok:bool,msg:string,createdCountries:int,createdNetworks:int,createdMncs:int}
     */
    public function import(string $source = 'itu', bool $fresh = false): array {
        $createdCountries = 0; $createdNetworks = 0; $createdMncs = 0;

        if ($fresh) {
            DB::table('network_mncs')->truncate();
            DB::table('country_mccs')->truncate();
        }

        $rows = $this->fetchRows($source);
        if (!is_array($rows) || empty($rows)) {
            return ['ok'=>false,'msg'=>'No data fetched','createdCountries'=>0,'createdNetworks'=>0,'createdMncs'=>0];
        }

        $networkMncRows = [];
        $seenMccMnc     = [];   // "mcc|mnc" => true
        $mccToCountry   = [];   // mcc => country_id

        DB::transaction(function () use ($rows, &$createdCountries, &$createdNetworks, &$networkMncRows, &$seenMccMnc, &$mccToCountry) {
            foreach ($rows as $r) {
                $mcc = trim((string)($r['mcc'] ?? $r['MCC'] ?? ''));
                $mnc = trim((string)($r['mnc'] ?? $r['MNC'] ?? ''));
                $countryName = trim((string)($r['country'] ?? $r['country_name'] ?? $r['countryName'] ?? ''));
                $iso2  = strtolower(trim((string)($r['iso'] ?? $r['iso2'] ?? $r['country_code'] ?? '')));
                $brand = trim((string)($r['brand'] ?? $r['operator'] ?? $r['network'] ?? ''));

                if ($mcc === '' || $mnc === '' || $countryName === '' || $brand === '') {
                    continue;
                }
                if (!ctype_digit($mcc) || !ctype_digit($mnc)) {
                    continue;
                }

                $mccInt = (int)$mcc;
                $mncInt = (int)$mnc;

                // Country (create if missing)
                $country = Country::firstOrCreate(
                    ['name' => $countryName],
                    ['iso2' => $iso2 ?: null]
                );
                if ($country->wasRecentlyCreated) { $createdCountries++; }

                // Network match by (country_id, lower(name))
                $lname = Str::lower($brand);
                $network = Network::where('country_id', $country->id)
                    ->whereRaw('lower(name) = ?', [$lname])
                    ->first();

                if (!$network) {
                    $network = Network::create([
                        'country_id' => $country->id,
                        'name'       => $brand,
                        'lower_name' => $lname,
                    ]);
                    $createdNetworks++;
                }

                // country_mccs: one row per MCC overall (DB has unique on mcc)
                if (!array_key_exists($mccInt, $mccToCountry)) {
                    $mccToCountry[$mccInt] = $country->id; // first seen wins
                }

                // network_mncs: dedupe by (mcc,mnc) before upsert
                $key = $mccInt.'|'.$mncInt;
                if (!isset($seenMccMnc[$key])) {
                    $seenMccMnc[$key] = true;
                    $networkMncRows[] = [
                        'network_id' => $network->id,
                        'mcc'        => $mccInt,
                        'mnc'        => $mncInt,
                        'mcc_mnc'    => ($mccInt * 1000) + $mncInt, // keeps 2-3 digit MNC distinct
                        'created_at' => now(),
                        'updated_at' => now(),
                    ];
                }
            }

            // Upsert country_mccs by mcc (aligns with country_mccs_mcc_unique)
            if (!empty($mccToCountry)) {
                $rows = [];
                $now = now();
                foreach ($mccToCountry as $mcc => $cid) {
                    $rows[] = ['mcc' => (int)$mcc, 'country_id' => (int)$cid, 'created_at' => $now, 'updated_at' => $now];
                }
                DB::table('country_mccs')->upsert($rows, ['mcc'], ['country_id','updated_at']);
            }

            // Upsert network_mncs by (mcc,mnc) (aligns with nx_network_mncs_mcc_mnc)
            if (!empty($networkMncRows)) {
                DB::table('network_mncs')->upsert(
                    $networkMncRows,
                    ['mcc','mnc'],
                    ['network_id','mcc_mnc','updated_at']
                );
            }
        });

        $createdMncs = count($networkMncRows);

        return [
            'ok' => true,
            'msg' => 'Import finished',
            'createdCountries' => $createdCountries,
            'createdNetworks'  => $createdNetworks,
            'createdMncs'      => $createdMncs,
        ];
    }

    /** @return array<int, array<string,mixed>> */
    private function fetchRows(string $source): array {
        $urls = [
            // Stable community mirror
            'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
        ];
        foreach ($urls as $url) {
            try {
                $res = Http::timeout(30)->get($url);
                if ($res->successful()) {
                    $data = $res->json();
                    if (is_array($data) && count($data)) {
                        return $data;
                    }
                }
            } catch (\Throwable $e) {}
        }
        // Local fallback if present
        $fallback = resource_path('data/mcc-mnc-table.json');
        if (is_file($fallback)) {
            $data = json_decode((string)@file_get_contents($fallback), true);
            if (is_array($data)) return $data;
        }
        return [];
    }
}
PHP

echo "==> Lint & warm caches"
$DC exec -T app sh -lc '
  php -l app/Services/CarrierImportService.php
  php artisan optimize:clear
  composer dump-autoload -o
'

echo "==> BEFORE counts"
$DC exec -T app sh -lc '
php -r "
require __DIR__ . \"/vendor/autoload.php\";
\$app = require __DIR__ . \"/bootstrap/app.php\";
\$kernel = \$app->make(Illuminate\Contracts\Console\Kernel::class); \$kernel->bootstrap();
use Illuminate\Support\Facades\DB;
echo json_encode([
  \"countries\"=>DB::table(\"countries\")->count(),
  \"country_mccs\"=>DB::table(\"country_mccs\")->count(),
  \"networks\"=>DB::table(\"networks\")->count(),
  \"network_mncs\"=>DB::table(\"network_mncs\")->count(),
], JSON_PRETTY_PRINT), PHP_EOL;
"
'

echo "==> Run importer (fresh)"
$DC exec -T app sh -lc 'php artisan carriers:import --fresh -v || true'

echo "==> AFTER counts"
$DC exec -T app sh -lc '
php -r "
require __DIR__ . \"/vendor/autoload.php\";
\$app = require __DIR__ . \"/bootstrap/app.php\";
\$kernel = \$app->make(Illuminate\Contracts\Console\Kernel::class); \$kernel->bootstrap();
use Illuminate\Support\Facades\DB;
echo json_encode([
  \"countries\"=>DB::table(\"countries\")->count(),
  \"country_mccs\"=>DB::table(\"country_mccs\")->count(),
  \"networks\"=>DB::table(\"networks\")->count(),
  \"network_mncs\"=>DB::table(\"network_mncs\")->count(),
], JSON_PRETTY_PRINT), PHP_EOL;
"
'

echo "==> Samples"
$DC exec -T app sh -lc '
php -r "
require __DIR__ . \"/vendor/autoload.php\";
\$app = require __DIR__ . \"/bootstrap/app.php\";
\$kernel = \$app->make(Illuminate\Contracts\Console\Kernel::class); \$kernel->bootstrap();
use Illuminate\Support\Facades\DB;
\$s = [
  \"country_mccs\"=>DB::table(\"country_mccs\")->orderBy(\"mcc\")->limit(5)->get(),
  \"network_mncs\"=>DB::table(\"network_mncs\")->orderBy(\"mcc\")->orderBy(\"mnc\")->limit(5)->get(),
];
echo json_encode(\$s, JSON_PRETTY_PRINT), PHP_EOL;
"
'

echo "==> Done. Log: $LOG"
