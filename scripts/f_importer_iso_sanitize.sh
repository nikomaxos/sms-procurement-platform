#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p app/Console/Commands

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

        $push = function(array &$arr, string $country, string $iso, string $mcc, string $mnc, string $name){
            $iso2 = preg_match('/^[a-z]{2}$/', strtolower($iso)) ? strtolower($iso) : null; // sanitize to 2 letters or NULL
            // allow "International Networks" etc; it will get iso2 = NULL
            $mcc = trim($mcc); $mnc = trim($mnc);
            if ($country !== '' && $mcc !== '' && $mnc !== '') {
                $arr[] = ['country'=>$country, 'iso2'=>$iso2, 'mcc'=>$mcc, 'mnc'=>$mnc, 'name'=>$name !== '' ? $name : 'Unknown'];
            }
        };

        $norm = [];
        if ($raw = $fetch($this->jsonUrl)) {
            $j = json_decode($raw, true);
            if (is_array($j)) foreach ($j as $row) {
                $country = trim((string)($row['country'] ?? ($row['country_name'] ?? '')));
                $iso     = trim((string)($row['iso']     ?? ($row['iso2']         ?? '')));
                $mcc     = trim((string)($row['mcc']     ?? ''));
                $mnc     = trim((string)($row['mnc']     ?? ''));
                $name    = trim((string)($row['brand']   ?? ($row['operator']     ?? ($row['network'] ?? ''))));
                $push($norm,$country,$iso,$mcc,$mnc,$name);
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
                        $row = @array_combine($hdr, array_pad($cols, count($hdr), null));
                        if (!$row) continue;
                        $country = trim((string)($row['country'] ?? ($row['country_name'] ?? '')));
                        $iso     = trim((string)($row['iso']     ?? ($row['iso2']         ?? '')));
                        $mcc     = trim((string)($row['mcc']     ?? ''));
                        $mnc     = trim((string)($row['mnc']     ?? ''));
                        $name    = trim((string)($row['brand']   ?? ($row['operator']     ?? ($row['network'] ?? ''))));
                        $push($norm,$country,$iso,$mcc,$mnc,$name);
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

            // Countries
            $idByCountry = [];
            foreach ($norm as $n) {
                if (!isset($idByCountry[$n['country']])){
                    $c = Country::firstOrCreate(
                        ['name'=>$n['country']],
                        ['iso2'=>$n['iso2']] // <= can be NULL, OK
                    );
                    $idByCountry[$n['country']] = $c->id;
                }
            }

            // MCC map
            $seenMcc = [];
            foreach ($norm as $n) {
                if (isset($seenMcc[$n['mcc']])) continue;
                $seenMcc[$n['mcc']] = true;
                $cid = $idByCountry[$n['country']] ?? null;
                if ($cid) { CountryMcc::firstOrCreate(['mcc'=>$n['mcc']], ['country_id'=>$cid]); }
            }

            $cidByMcc = CountryMcc::pluck('country_id','mcc')->all();

            // Networks
            foreach ($norm as $n) {
                $mccPad = str_pad($n['mcc'],3,'0',STR_PAD_LEFT);
                // MNC can be 2 or 3 digits in datasets; keep original for form, pad for key
                $mncKey = str_pad(preg_replace('/\D/','',$n['mnc']),3,'0',STR_PAD_LEFT);
                $key = $mccPad.$mncKey;

                $net = Network::firstOrNew(['mcc_mnc'=>$key]);
                $net->name = $n['name'];
                $net->mcc  = $mccPad;
                $net->mnc  = $n['mnc'];
                $net->country_id = $cidByMcc[$mccPad] ?? null;
                $net->save();
            }
        });

        $this->info("Imported => Countries: ".Country::count()." | MCCs: ".CountryMcc::count()." | Networks: ".Network::count());
        return 0;
    }
}
PHP

echo "Importer updated."
