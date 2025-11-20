#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Step1b: overwrite service + wire command"

############################################
# 1) Overwrite App\Services\CarrierImportService
############################################
F=app/Services/CarrierImportService.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use App\Models\Country;
use App\Models\Network;

/**
 * Imports MCC/MNC dataset into:
 *  - countries (id, name, iso2)
 *  - networks (id, country_id, name, lower_name, marked)
 *  - country_mccs (country_id, mcc)
 *  - network_mncs (network_id, mcc, mnc, mcc_mnc)
 */
class CarrierImportService {
    /**
     * @return array{ok:bool,msg:string,createdCountries:int,createdNetworks:int,createdMncs:int}
     */
    public function import(string $source, bool $fresh): array {
        $createdCountries = 0; $createdNetworks = 0; $createdMncs = 0;

        if ($fresh) {
            DB::table('network_mncs')->truncate();
            DB::table('country_mccs')->truncate();
            // Keep networks / countries; importer will upsert
        }

        $urls = [
            // A reliable public mirror of ITU data
            'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
        ];

        $rows = [];
        foreach ($urls as $url) {
            try {
                $res = Http::timeout(30)->get($url);
                if ($res->successful()) {
                    $data = $res->json();
                    if (is_array($data)) { $rows = array_merge($rows, $data); }
                }
            } catch (\Throwable $e) {
                // ignore and continue
            }
        }
        if (!$rows) {
            return ['ok'=>false,'msg'=>'No data fetched','createdCountries'=>0,'createdNetworks'=>0,'createdMncs'=>0];
        }

        DB::transaction(function () use ($rows, &$createdCountries, &$createdNetworks, &$createdMncs) {
            foreach ($rows as $r) {
                // Be schema-tolerant
                $mcc     = trim((string)($r['mcc'] ?? $r['MCC'] ?? ''));
                $mnc     = trim((string)($r['mnc'] ?? $r['MNC'] ?? ''));
                $cname   = trim((string)($r['country'] ?? $r['country_name'] ?? $r['countryName'] ?? ''));
                $iso2    = strtolower(trim((string)($r['iso'] ?? $r['iso2'] ?? $r['country_code'] ?? '')));
                $netName = trim((string)($r['brand'] ?? $r['operator'] ?? $r['network'] ?? ''));

                if ($mcc === '' || $mnc === '' || $cname === '' || $netName === '') {
                    continue;
                }

                // Upsert country by (name, iso2?)
                $country = Country::firstOrCreate(
                    ['name' => $cname],
                    ['iso2' => $iso2 ?: null]
                );
                if ($country->wasRecentlyCreated) { $createdCountries++; }

                // Upsert network scoped by country + lower_name
                $lower = mb_strtolower($netName);
                $network = Network::where('country_id', $country->id)
                    ->where('lower_name', $lower)
                    ->first();

                if (!$network) {
                    $network = Network::create([
                        'country_id' => $country->id,
                        'name'       => $netName,
                        'lower_name' => $lower,
                        'marked'     => false,
                    ]);
                    $createdNetworks++;
                } else {
                    if ($network->name !== $netName) {
                        $network->name = $netName;
                        $network->save();
                    }
                }

                // Insert unique MCC for the country
                $cm = DB::table('country_mccs')->where([
                    'country_id' => $country->id,
                    'mcc'        => $mcc,
                ])->first();
                if (!$cm) {
                    DB::table('country_mccs')->insert([
                        'country_id' => $country->id,
                        'mcc' => $mcc,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }

                // Insert unique (network_id, mcc, mnc) in network_mncs
                $exists = DB::table('network_mncs')->where([
                    'network_id' => $network->id,
                    'mcc'        => $mcc,
                    'mnc'        => $mnc,
                ])->first();

                if (!$exists) {
                    DB::table('network_mncs')->insert([
                        'network_id' => $network->id,
                        'mcc'        => $mcc,
                        'mnc'        => $mnc,
                        'mcc_mnc'    => $mcc.$mnc,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                    $createdMncs++;
                }
            }
        });

        return [
            'ok' => true,
            'msg' => 'done',
            'createdCountries' => $createdCountries,
            'createdNetworks'  => $createdNetworks,
            'createdMncs'      => $createdMncs,
        ];
    }
}
PHP

############################################
# 2) Add a clean console command that calls the service
############################################
D=app/Console/Commands; mkdir -p "$D"
F="$D/CarriersImport.php"
b "$F"
cat > "$F" <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\CarrierImportService;

class CarriersImport extends Command
{
    protected $signature = 'carriers:import {--source=itu} {--fresh}';
    protected $description = 'Import carriers (countries/networks) + MCC/MNC links using CarrierImportService (prints JSON summary)';

    public function handle(): int {
        $source = (string)$this->option('source');
        $fresh  = (bool)$this->option('fresh');

        $svc = new CarrierImportService();
        $res = $svc->import($source, $fresh);

        $this->line(json_encode($res, JSON_PRETTY_PRINT));
        return $res['ok'] ? Command::SUCCESS : Command::FAILURE;
    }
}
PHP

############################################
# 3) Ensure Kernel registers our command, and disable any route-console closure
############################################
K=app/Console/Kernel.php
if [ -f "$K" ]; then
  b "$K"
  # Add use if missing
  grep -q "use App\\Console\\Commands\\CarriersImport;" "$K" || \
    sed -i '1i <?php\n\nnamespace App\\Console;\n\nuse Illuminate\\Console\\Scheduling\\Schedule;\nuse Illuminate\\Foundation\\Console\\Kernel as ConsoleKernel;\nuse App\\Console\\Commands\\CarriersImport;\n' "$K"

  # Ensure $commands[] includes our command (idempotent)
  if ! grep -q "CarriersImport::class" "$K"; then
    # Insert into class body; create commands array if missing
    if ! grep -q "protected \$commands" "$K"; then
      # Insert property near top of class
      sed -i 's/class Kernel extends ConsoleKernel {/class Kernel extends ConsoleKernel {\n    protected $commands = [\\App\\Console\\Commands\\CarriersImport::class];/g' "$K"
    else
      sed -i 's/protected \$commands = \[/protected \$commands = [\\App\\Console\\Commands\\CarriersImport::class, /' "$K"
    fi
  fi
fi

# Comment any closure commands in routes/console.php that mention carriers:import
if [ -f routes/console.php ]; then
  b routes/console.php
  sed -i 's/\(carriers:import\)/\/\/ \1/g' routes/console.php || true
fi

############################################
# 4) Autoload + quick lint
############################################
$DC exec -T app sh -lc '
  php -l app/Services/CarrierImportService.php
  php -l app/Console/Commands/CarriersImport.php
  composer dump-autoload -o
'

echo "==> Verify which carriers:import is active"
$DC exec -T app sh -lc 'php artisan help carriers:import'

echo "==> Run fresh import using the new command"
$DC exec -T app sh -lc 'php artisan carriers:import --fresh -v || true'

echo "==> Show row counts"
$DC exec -T app sh -lc '\''php artisan tinker --execute '\''
echo json_encode([
 "countries"=>DB::table("countries")->count(),
 "country_mccs"=>DB::table("country_mccs")->count(),
 "networks"=>DB::table("networks")->count(),
 "network_mncs"=>DB::table("network_mncs")->count()
], JSON_PRETTY_PRINT);
'\'''\'

echo "==> Step1b done."
