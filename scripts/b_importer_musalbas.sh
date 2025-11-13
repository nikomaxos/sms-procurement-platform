#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p app/Console/Commands app/Console

cat > app/Console/Commands/ImportCarriers.php <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use App\Models\Country;
use App\Models\CountryMcc;
use App\Models\Network;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--fresh}';
    protected $description = 'Import Countries/MCC and Networks/MCC-MNC from musalbas/mcc-mnc-table';

    private string $jsonUrl = 'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json';
    private string $csvUrl  = 'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.csv';

    public function handle(): int {
        $fresh = (bool)$this->option('fresh');
        $fetch = function (string $url): ?string {
            $ctx = stream_context_create(['http'=>['timeout'=>30],'https'=>['timeout'=>30]]);
            $raw = @file_get_contents($url,false,$ctx);
            return $raw === false ? null : $raw;
        };

        $norm = [];
        if ($raw = $fetch($this->jsonUrl)) {
            $j = json_decode($raw, true);
            if (is_array($j)) foreach ($j as $row) {
                $mcc = trim((string)($row['mcc'] ?? ''));
                $mnc = trim((string)($row['mnc'] ?? ''));
                $country = trim((string)($row['country'] ?? ($row['country_name'] ?? '')));
                $iso = strtolower(trim((string)($row['iso'] ?? ($row['iso2'] ?? ''))));
                $name = trim((string)($row['brand'] ?? ($row['operator'] ?? ($row['network'] ?? 'Unknown'))));
                if ($mcc && $mnc && $country) $norm[] = compact('country','iso','mcc','mnc','name');
            }
        }

        if (!$norm) {
            if ($csv = $fetch($this->csvUrl)) {
                $lines = preg_split("/\r\n|\n|\r/", trim($csv));
                if ($lines && count($lines) > 1) {
                    $hdr = array_map('strtolower', str_getcsv(array_shift($lines)));
                    foreach ($lines as $ln) {
                        if ($ln === '') continue;
                        $cols = str_getcsv($ln);
                        $row = array_combine($hdr, array_pad($cols, count($hdr), null));
                        if (!$row) continue;
                        $mcc = trim((string)($row['mcc'] ?? ''));
                        $mnc = trim((string)($row['mnc'] ?? ''));
                        $country = trim((string)($row['country'] ?? ($row['country_name'] ?? '')));
                        $iso = strtolower(trim((string)($row['iso'] ?? ($row['iso2'] ?? ''))));
                        $name = trim((string)($row['brand'] ?? ($row['operator'] ?? ($row['network'] ?? 'Unknown'))));
                        if ($mcc && $mnc && $country) $norm[] = compact('country','iso','mcc','mnc','name');
                    }
                }
            }
        }

        if (!$norm) { $this->error('No rows parsed from musalbas.'); return 1; }

        DB::transaction(function() use ($fresh,$norm) {
            if ($fresh) {
                DB::table('networks')->truncate();
                DB::table('country_mccs')->truncate();
                DB::table('countries')->truncate();
            }

            $idByCountry = [];
            foreach ($norm as $n) {
                $key = $n['country'];
                if (!isset($idByCountry[$key])) {
                    $c = Country::firstOrCreate(['name'=>$n['country']], ['iso2'=>$n['iso'] ?: null]);
                    $idByCountry[$key] = $c->id;
                }
            }

            $seenMcc = [];
            foreach ($norm as $n) {
                if (isset($seenMcc[$n['mcc']])) continue;
                $seenMcc[$n['mcc']] = true;
                $cid = $idByCountry[$n['country']] ?? null;
                if ($cid) CountryMcc::firstOrCreate(['mcc'=>$n['mcc']], ['country_id'=>$cid]);
            }

            $cidByMcc = CountryMcc::pluck('country_id','mcc')->all();

            foreach ($norm as $n) {
                $mcc = str_pad($n['mcc'],3,'0',STR_PAD_LEFT);
                $mnc = ltrim($n['mnc']);
                $mncPad = str_pad($mnc,3,'0',STR_PAD_LEFT);
                $key = $mcc.$mncPad;

                $net = Network::firstOrNew(['mcc_mnc'=>$key]);
                $net->name = $n['name'] ?: 'Unknown';
                $net->mcc  = $mcc;
                $net->mnc  = $mnc;
                $net->country_id = $cidByMcc[$mcc] ?? null;
                $net->save();
            }
        });

        $this->info("Imported => Countries: ".Country::count()." | MCCs: ".CountryMcc::count()." | Networks: ".Network::count());
        return 0;
    }
}
PHP

# Minimal Kernel that loads Commands directory
if [ ! -f app/Console/Kernel.php ]; then
  cat > app/Console/Kernel.php <<'PHP'
<?php
namespace App\Console;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel {
  protected function schedule(Schedule $schedule): void {}
  protected function commands(): void {
    $this->load(__DIR__.'/Commands');
    if (file_exists(base_path('routes/console.php'))) require base_path('routes/console.php');
  }
}
PHP
fi

echo "Importer and Kernel ready."
