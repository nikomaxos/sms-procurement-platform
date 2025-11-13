# scripts/switch_import_to_onomondo.sh
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

# Paths
IMPCMD="app/Console/Commands/ImportCarriers.php"
KERNEL="app/Console/Kernel.php"

mkdir -p "$(dirname "$IMPCMD")" app/Console

cat > "$IMPCMD" <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use App\Models\Country;
use App\Models\CountryMcc;
use App\Models\Network;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--fresh : Truncate and re-import all carriers}';
    protected $description = 'Import Countries (MCC) and Networks (MCC/MNC) — primary source: onomondo/mcc-mnc-itu';

    /** @var array<string> Candidate URLs (first that works is used) */
    private array $jsonUrls = [
        // onomondo (preferred) — [Inference]
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/mcc-mnc-itu.json',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/mcc-mnc-itu.json',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/data/mcc-mnc-itu.json',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/data/mcc-mnc-itu.json',
        // fallbacks (to avoid empty datasets) — [Inference]
        'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
        'https://raw.githubusercontent.com/opencellid/mcc-mnc-table/master/mcc-mnc-table.json',
    ];
    /** @var array<string> CSV fallbacks */
    private array $csvUrls = [
        // onomondo (CSV) — [Inference]
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/mcc-mnc-itu.csv',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/mcc-mnc-itu.csv',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/main/data/mcc-mnc-itu.csv',
        'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/data/mcc-mnc-itu.csv',
        // fallbacks
        'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.csv',
        'https://raw.githubusercontent.com/opencellid/mcc-mnc-table/master/mcc-mnc-table.json', // sometimes JSON in CSV list
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

        // ---- pull data (try JSON first) ----
        $norm = [];
        $raw  = $fetch($this->jsonUrls);
        if ($raw) {
            $json = json_decode($raw, true);
            if (is_array($json)) {
                foreach ($json as $row) {
                    $this->pushRow($norm, $row);
                }
            }
        }

        // ---- CSV fallback ----
        if (!$norm) {
            $csv = $fetch($this->csvUrls);
            if ($csv) {
                $lines = preg_split("/\r\n|\n|\r/", trim($csv));
                if ($lines && count($lines) > 1) {
                    $hdr = array_map(fn($h)=>strtolower(trim($h)), str_getcsv(array_shift($lines)));
                    foreach ($lines as $ln) {
                        if ($ln==='') continue;
                        $cols = str_getcsv($ln);
                        $row  = @array_combine($hdr, array_pad($cols, count($hdr), null));
                        if (!$row) continue;
                        $this->pushRow($norm, $row);
                    }
                }
            }
        }

        if (!$norm) {
            $this->error('No data parsed from any source.');
            return self::FAILURE;
        }

        DB::transaction(function() use ($norm, $fresh) {
            if ($fresh) {
                // Clean tables (Postgres-safe)
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

            $countryByMcc = []; // mcc => country_id

            foreach ($norm as $r) {
                $countryName = $r['country'] ?: 'Unknown';
                $iso2 = $this->sanitizeIso2($r['iso2']);
                $mcc  = $this->digits($r['mcc'], 3);
                $mnc  = $this->digits($r['mnc'], 3); // keep 2/3 as given
                $name = $r['name'] ?: 'Unknown';

                if (!$mcc) continue;

                // Country
                $country = Country::firstOrCreate(
                    ['name' => $countryName],
                    ['iso2' => $iso2 ?: null]
                );
                if ($iso2 && (!$country->iso2 || $country->iso2 === 'n/a')) {
                    $country->iso2 = $iso2;
                    $country->save();
                }

                // Country MCC (unique on mcc)
                $cm = CountryMcc::where('mcc', $mcc)->first();
                if (!$cm) {
                    CountryMcc::create(['country_id' => $country->id, 'mcc' => $mcc]);
                } elseif ($cm->country_id !== $country->id) {
                    // re-assign if needed
                    $cm->country_id = $country->id;
                    $cm->save();
                }
                $countryByMcc[$mcc] = $country->id;

                // Network (only if we have mnc)
                if ($mnc) {
                    $mcc_mnc = $mcc . $mnc; // 3+2/3 chars
                    $net = Network::where('mcc_mnc', $mcc_mnc)->first();
                    if (!$net) {
                        $net = new Network();
                        $net->mcc = $mcc;
                        $net->mnc = $mnc;
                        $net->mcc_mnc = $mcc_mnc;
                    }
                    $net->name = $name;
                    $net->country_id = $country->id;
                    $net->save();
                }
            }
        });

        $this->info('Import complete. Countries: '.Country::count().' | Networks: '.Network::count());
        return self::SUCCESS;
    }

    /** Normalize & collect a row into $norm */
    private function pushRow(array &$norm, array $row): void {
        $get = function(array $keys) use ($row) {
            foreach ($keys as $k) {
                if (array_key_exists($k, $row) && $row[$k] !== null && $row[$k] !== '') return $row[$k];
                // allow case variations and dashes/underscores
                foreach ($row as $rk => $val) {
                    $kk = strtolower(str_replace(['-',' '],'_', (string)$rk));
                    if ($kk === strtolower(str_replace(['-',' '],'_', (string)$k))) return $val;
                }
            }
            return null;
        };

        $country = trim((string)($get(['country','country_name','Country']) ?? ''));
        $iso2    = trim((string)($get(['iso','iso2','alpha_2','Alpha-2']) ?? ''));
        $mcc     = trim((string)($get(['mcc','MCC']) ?? ''));
        $mnc     = trim((string)($get(['mnc','MNC']) ?? ''));
        $name    = trim((string)($get(['brand','operator','Operator','Operator/Network','network','Network','brand_name']) ?? ''));

        // Some ITU rows might name the operator in different fields
        if ($name === '' && $country !== '' && $mcc !== '') {
            $name = 'Operator '.$mcc.($mnc!==''?('-'.$mnc):'');
        }

        $norm[] = [
            'country' => $country,
            'iso2'    => $iso2,
            'mcc'     => $mcc,
            'mnc'     => $mnc,
            'name'    => $name,
        ];
    }

    private function sanitizeIso2(?string $iso2): ?string {
        $iso2 = $iso2 ? strtolower(trim($iso2)) : '';
        if ($iso2 === '' || $iso2 === 'na' || $iso2 === 'n/a') return 'n/a';
        // keep up to 3 to tolerate 'n/a' or special tags
        return substr($iso2, 0, 3);
    }

    private function digits(?string $s, int $max): string {
        if ($s===null) return '';
        $d = preg_replace('/\D+/', '', (string)$s);
        if ($d === null) $d = '';
        // keep original width up to $max (mnc can be 2 or 3; mcc 3)
        return substr($d, 0, $max);
    }
}
PHP

# Make sure the Console Kernel loads Commands (idempotent)
if [ -f "$KERNEL" ]; then
  php -r '
    $f="'$KERNEL'";
    $s=file_get_contents($f);
    if(strpos($s,"class Kernel")!==false && strpos($s,"function commands()")===false){
      $s=preg_replace("/class\\s+Kernel\\s+extends\\s+ConsoleKernel\\s*\\{/",
        "class Kernel extends ConsoleKernel {\\n    protected function commands(): void {\\n        \$this->load(__DIR__ . \"/Commands\");\\n        if (file_exists(base_path(\"routes/console.php\"))) require base_path(\"routes/console.php\");\\n    }\\n",
        $s,1);
      file_put_contents($f,$s);
    }
  '
fi

echo "Importer switched to onomondo-first with robust fallbacks."
