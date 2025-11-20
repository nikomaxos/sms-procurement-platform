#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

LOG="logs/step1b_resume_$ts.log"
mkdir -p logs
exec > >(tee -a "$LOG") 2>&1

echo "==> Step1b-resume: verify & (re)apply importer + command — logging to $LOG"

############################################
# 0) Minimal carriers/import UI view (in case it's missing)
############################################
V=resources/views/carriers/import.blade.php
if [ ! -f "$V" ]; then
  echo "==> Creating carriers import view"
  mkdir -p "$(dirname "$V")"
  cat > "$V" <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl">Carriers Import</h2></x-slot>
  <div class="max-w-3xl mx-auto mt-6 p-6 bg-white rounded shadow">
    <form method="POST" action="{{ route('carriers.import') }}">
      @csrf
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium">Source</label>
          <select name="source" class="mt-1 border rounded px-3 py-2 w-full">
            <option value="itu" selected>ITU JSON (mirror)</option>
          </select>
        </div>
        <div class="flex items-center gap-2">
          <input type="checkbox" id="fresh" name="fresh" value="1" class="h-4 w-4">
          <label for="fresh" class="text-sm">Fresh (truncate country_mccs & network_mncs)</label>
        </div>
      </div>
      <div class="mt-6">
        <button class="bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700">Run Import</button>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE
fi

############################################
# 1) Overwrite App\Services\CarrierImportService (backup first)
############################################
echo "==> Ensuring App\\Services\\CarrierImportService exists & is complete"
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
        }

        $urls = [
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
                $mcc     = trim((string)($r['mcc'] ?? $r['MCC'] ?? ''));
                $mnc     = trim((string)($r['mnc'] ?? $r['MNC'] ?? ''));
                $cname   = trim((string)($r['country'] ?? $r['country_name'] ?? $r['countryName'] ?? ''));
                $iso2    = strtolower(trim((string)($r['iso'] ?? $r['iso2'] ?? $r['country_code'] ?? '')));
                $netName = trim((string)($r['brand'] ?? $r['operator'] ?? $r['network'] ?? ''));

                if ($mcc === '' || $mnc === '' || $cname === '' || $netName === '') {
                    continue;
                }

                // Upsert country
                $country = Country::firstOrCreate(
                    ['name' => $cname],
                    ['iso2' => $iso2 ?: null]
                );
                if ($country->wasRecentlyCreated) { $createdCountries++; }

                // Upsert network per (country, lower_name)
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

                // Country MCC (unique)
                if (!DB::table('country_mccs')->where([
                    'country_id' => $country->id,
                    'mcc'        => $mcc,
                ])->exists()) {
                    DB::table('country_mccs')->insert([
                        'country_id' => $country->id,
                        'mcc'        => $mcc,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }

                // Network MNC (unique per network + mcc + mnc)
                if (!DB::table('network_mncs')->where([
                    'network_id' => $network->id,
                    'mcc'        => $mcc,
                    'mnc'        => $mnc,
                ])->exists()) {
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
# 2) Console command that calls the service
############################################
echo "==> Ensuring console command is present"
D=app/Console/Commands; mkdir -p "$D"
CF="$D/CarriersImport.php"
b "$CF"
cat > "$CF" <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\CarrierImportService;

class CarriersImport extends Command
{
    protected $signature = 'carriers:import {--source=itu} {--fresh}';
    protected $description = 'Import carriers using CarrierImportService (prints JSON summary)';

    public function handle(): int {
        $svc = new CarrierImportService();
        $res = $svc->import((string)$this->option('source'), (bool)$this->option('fresh'));
        $this->line(json_encode($res, JSON_PRETTY_PRINT));
        return $res['ok'] ? Command::SUCCESS : Command::FAILURE;
    }
}
PHP

############################################
# 3) Register command in Kernel (idempotent)
############################################
echo "==> Registering command in Kernel"
K=app/Console/Kernel.php
b "$K"

# Ensure 'use' line exists
grep -q 'use App\\Console\\Commands\\CarriersImport;' "$K" || \
  sed -i 's/^namespace App\\Console;$/namespace App\\Console;\n\nuse App\\Console\\Commands\\CarriersImport;/' "$K"

# Ensure commands property includes our class
if ! grep -q 'CarriersImport::class' "$K"; then
  if grep -q 'protected \$commands' "$K"; then
    sed -i 's/protected \$commands = \[/protected $commands = [CarriersImport::class, /' "$K"
  else
    sed -i 's/class Kernel extends ConsoleKernel {/class Kernel extends ConsoleKernel {\n    protected $commands = [CarriersImport::class];/' "$K"
  fi
fi

# Comment legacy closures in routes/console.php if they mention carriers:import
if [ -f routes/console.php ]; then
  sed -i 's/\(carriers:import\)/\/\/ \1/g' routes/console.php || true
fi

############################################
# 4) Autoload, lint, migrate
############################################
$DC exec -T app sh -lc '
  php -l app/Services/CarrierImportService.php
  php -l app/Console/Commands/CarriersImport.php
  composer dump-autoload -o
  php artisan migrate --force
'

############################################
# 5) Show which carriers:import is active
############################################
$DC exec -T app sh -lc 'php artisan help carriers:import || true'

############################################
# 6) Run a fresh import and display row counts
############################################
$DC exec -T app sh -lc 'php artisan carriers:import --fresh -v || true'

$DC exec -T app sh -lc \
  'php artisan tinker --execute "echo json_encode([\"countries\"=>DB::table(\"countries\")->count(),\"country_mccs\"=>DB::table(\"country_mccs\")->count(),\"networks\"=>DB::table(\"networks\")->count(),\"network_mncs\"=>DB::table(\"network_mncs\")->count()], JSON_PRETTY_PRINT);"'

echo "==> Done. Full log: $LOG"
