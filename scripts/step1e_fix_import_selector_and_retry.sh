#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
LOG="logs/step1e_$ts.log"; mkdir -p logs
exec > >(tee -a "$LOG") 2>&1
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Step1e: make importer match by LOWER(name) (align with unique index) + retry"

# 1) Service update (match on LOWER(name), still fill lower_name if present)
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
    public function import(string $source, bool $fresh = false): array {
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
            return ['ok'=>false,'msg'=>'No data fetched (remote/local)','createdCountries'=>0,'createdNetworks'=>0,'createdMncs'=>0];
        }

        $hasLowerCol = Schema::hasColumn('networks','lower_name');

        DB::transaction(function () use ($rows, &$createdCountries, &$createdNetworks, &$createdMncs, $hasLowerCol) {
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

                // IMPORTANT: match by same expression as the unique index: LOWER(name)
                $network = Network::where('country_id', $country->id)
                    ->whereRaw('LOWER(name) = ?', [$lower])
                    ->first();

                if (!$network) {
                    try {
                        $data = ['country_id'=>$country->id, 'name'=>$netName, 'marked'=>false];
                        if ($hasLowerCol) $data['lower_name'] = $lower;
                        $network = Network::create($data);
                        $createdNetworks++;
                    } catch (\Illuminate\Database\UniqueConstraintViolationException $e) {
                        // Another row already exists (or race): refetch using the same expression
                        $network = Network::where('country_id', $country->id)
                            ->whereRaw('LOWER(name) = ?', [$lower])
                            ->first();
                        if (!$network) { throw $e; }
                    }
                } else if ($hasLowerCol && ($network->lower_name ?? null) !== $lower) {
                    $network->lower_name = $lower;
                    $network->save();
                }

                // country_mccs
                if (!DB::table('country_mccs')->where(['country_id'=>$country->id,'mcc'=>$mcc])->exists()) {
                    DB::table('country_mccs')->insert([
                        'country_id'=>$country->id,'mcc'=>$mcc,
                        'created_at'=>now(),'updated_at'=>now()
                    ]);
                }

                // network_mncs
                if (!DB::table('network_mncs')->where(['network_id'=>$network->id,'mcc'=>$mcc,'mnc'=>$mnc])->exists()) {
                    DB::table('network_mncs')->insert([
                        'network_id'=>$network->id,'mcc'=>$mcc,'mnc'=>$mnc,
                        'mcc_mnc'=>$mcc.$mnc,'created_at'=>now(),'updated_at'=>now()
                    ]);
                    $createdMncs++;
                }
            }
        });

        return ['ok'=>true,'msg'=>'done','createdCountries'=>$createdCountries,'createdNetworks'=>$createdNetworks,'createdMncs'=>$createdMncs];
    }
}
PHP

# 2) Optimize & show possible duplicates before and after import
DUP='DB::select("SELECT country_id, LOWER(name) lname, COUNT(*) c FROM networks GROUP BY country_id, lname HAVING COUNT(*)>1 ORDER BY c DESC LIMIT 15"); echo json_encode($DUP, JSON_PRETTY_PRINT);'

$DC exec -T app sh -lc '
  php -l app/Services/CarrierImportService.php
  composer dump-autoload -o
  php artisan optimize:clear

  echo "==> Possible duplicates BEFORE (top 15):"
  php artisan tinker --execute '"'"$DUP"'"'

  echo "==> Run fresh import:"
  php artisan carriers:import --fresh -v || true

  echo "==> Possible duplicates AFTER (top 15):"
  php artisan tinker --execute '"'"$DUP"'"'

  echo "==> Row counts:"
  php artisan tinker --execute "echo json_encode([
    \"countries\"=>DB::table(\"countries\")->count(),
    \"country_mccs\"=>DB::table(\"country_mccs\")->count(),
    \"networks\"=>DB::table(\"networks\")->count(),
    \"network_mncs\"=>DB::table(\"network_mncs\")->count()
  ], JSON_PRETTY_PRINT);"
'
echo "==> Step1e done. Log: $LOG"
