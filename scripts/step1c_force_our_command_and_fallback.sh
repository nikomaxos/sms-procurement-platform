#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
LOG="logs/step1c_$ts.log"; mkdir -p logs
exec > >(tee -a "$LOG") 2>&1
echo "==> Step1c: force our carriers:import + add local fallback (log: $LOG)"

############################################
# 0) Retire any OTHER commands with carriers:import
############################################
echo "==> Disabling legacy carriers:import command classes"
mkdir -p tools/retired
# find php files declaring carriers:import (except our CarriersImport.php)
while IFS= read -r -d '' F; do
  if [[ "$(basename "$F")" != "CarriersImport.php" ]]; then
    b "$F"; mv "$F" "tools/retired/$(basename "$F").off.$ts" || true
    echo "   retired: $F"
  fi
done < <(grep -RIlZ --include='*.php' "carriers:import" app/Console/Commands 2>/dev/null || true)

############################################
# 1) Import service with remote + local fallback
############################################
echo "==> Writing App\\Services\\CarrierImportService (remote + fallback)"
SVC=app/Services/CarrierImportService.php
b "$SVC"; mkdir -p "$(dirname "$SVC")"
cat > "$SVC" <<'PHP'
<?php
namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
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

        // Remote sources (try in order)
        $urls = [
            // GitHub mirror (commonly used community table)
            'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
            // Alternative mirror (often same content)
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
            } catch (\Throwable $e) { /* continue */ }
            if (!empty($rows)) break;
        }

        // Local fallback (bundled file) if remote empty
        if (empty($rows)) {
            $local = base_path('resources/data/mcc-mnc-table.json');
            if (is_file($local)) {
                try {
                    $data = json_decode(file_get_contents($local), true);
                    if (is_array($data)) { $rows = $data; }
                } catch (\Throwable $e) { /* noop */ }
            }
        }

        if (empty($rows)) {
            return ['ok'=>false,'msg'=>'No data fetched (remote) and no local fallback','createdCountries'=>0,'createdNetworks'=>0,'createdMncs'=>0];
        }

        DB::transaction(function () use ($rows, &$createdCountries, &$createdNetworks, &$createdMncs) {
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
                $network = Network::where('country_id', $country->id)->where('lower_name', $lower)->first();
                if (!$network) {
                    $network = Network::create([
                        'country_id' => $country->id,
                        'name'       => $netName,
                        'lower_name' => $lower,
                        'marked'     => false,
                    ]);
                    $createdNetworks++;
                } else {
                    if ($network->name !== $netName) { $network->name = $netName; $network->save(); }
                }

                // Country MCC (unique)
                if (!DB::table('country_mccs')->where(['country_id'=>$country->id,'mcc'=>$mcc])->exists()) {
                    DB::table('country_mccs')->insert([
                        'country_id'=>$country->id, 'mcc'=>$mcc,
                        'created_at'=>now(), 'updated_at'=>now()
                    ]);
                }

                // Network MNC (unique per network+mcc+mnc)
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
# 2) Bundle local fallback JSON (small but valid)
############################################
echo "==> Bundling local fallback JSON (resources/data/mcc-mnc-table.json)"
mkdir -p resources/data
cat > resources/data/mcc-mnc-table.json <<'JSON'
[
  {"mcc":"202","mnc":"01","country":"Greece","iso":"gr","brand":"Cosmote"},
  {"mcc":"202","mnc":"05","country":"Greece","iso":"gr","brand":"Vodafone"},
  {"mcc":"202","mnc":"10","country":"Greece","iso":"gr","brand":"Nova"},
  {"mcc":"204","mnc":"04","country":"Netherlands","iso":"nl","brand":"Vodafone"},
  {"mcc":"204","mnc":"08","country":"Netherlands","iso":"nl","brand":"KPN"}
]
JSON

############################################
# 3) Our CarriersImport command (distinct description)
############################################
echo "==> Writing our CarriersImport command"
CMD=app/Console/Commands/CarriersImport.php
b "$CMD"; mkdir -p "$(dirname "$CMD")"
cat > "$CMD" <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\CarrierImportService;

class CarriersImport extends Command
{
    protected $signature = 'carriers:import {--source=itu} {--fresh}';
    protected $description = 'CarriersImport (service-backed) — uses remote JSON with local fallback, prints JSON summary';

    public function handle(): int {
        $svc = new CarrierImportService();
        $res = $svc->import((string)$this->option('source'), (bool)$this->option('fresh'));
        $this->line(json_encode($res, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
        return $res['ok'] ? Command::SUCCESS : Command::FAILURE;
    }
}
PHP

############################################
# 4) Register ONLY our command in Kernel
############################################
echo "==> Registering our command in Kernel"
K=app/Console/Kernel.php
b "$K"
# ensure use
grep -q 'use App\\Console\\Commands\\CarriersImport;' "$K" || \
  sed -i 's/^namespace App\\Console;$/namespace App\\Console;\n\nuse App\\Console\\Commands\\CarriersImport;/' "$K"
# ensure protected $commands exists & contains only our class (remove common legacy entries if any)
if grep -q 'protected \$commands' "$K"; then
  # replace the whole array with only our command
  sed -i 's/protected \$commands\s*=.*/protected $commands = [CarriersImport::class];/' "$K"
else
  sed -i 's/class Kernel extends ConsoleKernel {/class Kernel extends ConsoleKernel {\n    protected $commands = [CarriersImport::class];/' "$K"
fi

############################################
# 5) Autoload refresh and confirm active command
############################################
$DC exec -T app sh -lc '
  php -l app/Services/CarrierImportService.php
  php -l app/Console/Commands/CarriersImport.php
  composer dump-autoload -o
  php artisan help carriers:import | sed -n "1,5p"
'

############################################
# 6) Fresh import and counts
############################################
$DC exec -T app sh -lc '
  php artisan carriers:import --fresh -v
  php artisan tinker --execute "echo json_encode([\"countries\"=>DB::table(\"countries\")->count(),\"country_mccs\"=>DB::table(\"country_mccs\")->count(),\"networks\"=>DB::table(\"networks\")->count(),\"network_mncs\"=>DB::table(\"network_mncs\")->count()], JSON_PRETTY_PRINT);"
'
echo "==> Step1c complete. See $LOG"
