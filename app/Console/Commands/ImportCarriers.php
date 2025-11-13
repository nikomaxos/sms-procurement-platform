<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use App\Models\Country;
use App\Models\CountryMcc;
use App\Models\Network;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--fresh : Truncate and re-import all carriers}';
    protected $description = 'Import Countries (MCC) and Networks (MCC/MNC) — onomondo-first with fallbacks';

    private array $jsonUrls = [
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/mcc-mnc-itu.json',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/mcc-mnc-itu.json',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/data/mcc-mnc-itu.json',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/data/mcc-mnc-itu.json',
        // fallbacks
        'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
        'https://raw.githubusercontent.com/opencellid/mcc-mnc-table/master/mcc-mnc-table.json',
    ];
    private array $csvUrls = [
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/mcc-mnc-itu.csv',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/mcc-mnc-itu.csv',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/data/mcc-mnc-itu.csv',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/data/mcc-mnc-itu.csv',
        // fallbacks
        'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.csv',
    ];

    public function handle(): int {
        $fresh = (bool)$this->option('fresh');

        $fetch = function (array $urls): ?string {
            $ctx = stream_context_create(['http'=>['timeout'=>30], 'https'=>['timeout'=>30]]);
            foreach ($urls as $u) {
                $raw = @file_get_contents($u, false, $ctx);
                if ($raw !== false && strlen(trim($raw)) > 0) {
                    $this->line("Fetching: $u");
                    return $raw;
                }
            }
            return null;
        };

        $norm = [];
        if ($raw = $fetch($this->jsonUrls)) {
            $json = json_decode($raw, true);
            if (is_array($json)) foreach ($json as $row) $this->pushRow($norm, $row);
        }
        if (!$norm) {
            if ($csv = $fetch($this->csvUrls)) {
                $lines = preg_split("/\r\n|\n|\r/", trim($csv));
                if ($lines && count($lines) > 1) {
                    $hdr = array_map(fn($h)=>strtolower(trim($h)), str_getcsv(array_shift($lines)));
                    foreach ($lines as $ln) {
                        if ($ln==='') continue;
                        $cols = str_getcsv($ln);
                        $row  = @array_combine($hdr, array_pad($cols, count($hdr), null));
                        if ($row) $this->pushRow($norm, $row);
                    }
                }
            }
        }
        if (!$norm) { $this->error('No data parsed from any source.'); return self::FAILURE; }

        DB::transaction(function() use ($norm, $fresh) {
            if ($fresh) {
                try {
                    DB::statement('TRUNCATE networks RESTART IDENTITY CASCADE');
                    DB::statement('TRUNCATE country_mccs RESTART IDENTITY CASCADE');
                    DB::statement('TRUNCATE countries RESTART IDENTITY CASCADE');
                } catch (\Throwable $e) {
                    DB::table('networks')->delete();
                    DB::table('country_mccs')->delete();
                    DB::table('countries')->delete();
                }
            }

            foreach ($norm as $r) {
                $countryName = $r['country'] ?: 'Unknown';
                $iso2 = $this->sanitizeIso2($r['iso2']);
                $mcc  = $this->digits($r['mcc'], 3);
                $mnc  = $this->digits($r['mnc'], 3);
                $name = $r['name'] ?: 'Unknown';

                if (!$mcc) continue;

                // Countries: ONLY valid 2-letter ISO2s, else NULL (avoid 'n/a' etc.)
                $attrs = ['name' => $countryName];
                $vals  = [];
                if ($iso2 !== null) $vals['iso2'] = $iso2; // don’t force invalid placeholders
                $country = Country::firstOrCreate($attrs, $vals);
                if ($iso2 !== null && $country->iso2 !== $iso2) {
                    $country->iso2 = $iso2;
                    $country->save();
                }

                // Country MCC (unique mcc)
                $cm = CountryMcc::where('mcc', $mcc)->first();
                if (!$cm) CountryMcc::create(['country_id' => $country->id, 'mcc' => $mcc]);
                else if ($cm->country_id !== $country->id) { $cm->country_id = $country->id; $cm->save(); }

                // Networks
                if ($mnc) {
                    $mcc_mnc = $mcc.$mnc;
                    $net = Network::where('mcc_mnc', $mcc_mnc)->first();
                    if (!$net) $net = new Network();
                    $net->mcc = $mcc;
                    $net->mnc = $mnc;
                    $net->mcc_mnc = $mcc_mnc;
                    $net->name = $name;
                    $net->country_id = $country->id;
                    $net->save();
                }
            }
        });

        $this->info('Import complete. Countries: '.Country::count().' | Networks: '.Network::count());
        return self::SUCCESS;
    }

    private function pushRow(array &$norm, array $row): void {
        $get = function(array $keys) use ($row) {
            foreach ($keys as $k) {
                if (array_key_exists($k,$row) && $row[$k]!==null && $row[$k]!=='') return $row[$k];
                foreach ($row as $rk=>$val) {
                    $kk = strtolower(str_replace(['-',' '], '_', (string)$rk));
                    if ($kk === strtolower(str_replace(['-',' '], '_', (string)$k))) return $val;
                }
            }
            return null;
        };
        $country = trim((string)($get(['country','country_name']) ?? ''));
        $iso2    = trim((string)($get(['iso','iso2','alpha_2']) ?? ''));
        $mcc     = trim((string)($get(['mcc']) ?? ''));
        $mnc     = trim((string)($get(['mnc']) ?? ''));
        $name    = trim((string)($get(['brand','operator','operator/network','network','brand_name']) ?? ''));

        if ($name === '' && $mcc !== '') $name = 'Operator '.$mcc.($mnc!==''?('-'.$mnc):'');
        $norm[] = ['country'=>$country,'iso2'=>$iso2,'mcc'=>$mcc,'mnc'=>$mnc,'name'=>$name];
    }

    private function sanitizeIso2(?string $iso2): ?string {
        if ($iso2===null) return null;
        $iso2 = strtolower(trim($iso2));
        // accept exactly 2 letters (e.g., 'gr', 'us'); otherwise NULL
        return preg_match('/^[a-z]{2}$/', $iso2) ? $iso2 : null;
    }

    private function digits(?string $s, int $max): string {
        if ($s===null) return '';
        $d = preg_replace('/\D+/', '', (string)$s) ?? '';
        return substr($d, 0, $max); // mcc=3; mnc up to 3 (2/3 both allowed)
    }
}
