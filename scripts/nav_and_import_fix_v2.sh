#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

SIDEBAR="resources/views/partials/sidebar.blade.php"
LINKS="resources/views/partials/countries_networks_links.blade.php"
IMPCMD="app/Console/Commands/ImportCarriers.php"
KERNEL="app/Console/Kernel.php"

echo "==> 0) Ensure dirs"
mkdir -p resources/views/partials app/Console/Commands

echo "==> 1) Create nav partial (Countries, Networks)"
cat > "$LINKS" <<'BLADE'
{{-- Added by nav_and_import_fix_v2 --}}
<a href="{{ route('countries.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
  <span class="material-icons text-sm">public</span>
  <span>Countries</span>
</a>
<a href="{{ route('networks.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
  <span class="material-icons text-sm">cell_tower</span>
  <span>Networks</span>
</a>
<hr class="my-2 opacity-30" />
BLADE

echo "==> 2) Inject @include at TOP of sidebar (once, idempotent)"
if [ -f "$SIDEBAR" ]; then
  cp -a "$SIDEBAR" "$SIDEBAR.bak.$(date +%F_%H-%M-%S)"
  if ! grep -q "partials.countries_networks_links" "$SIDEBAR"; then
    # Prepend include line at very top (ensures above Settings)
    printf "@include('partials.countries_networks_links')\n%s" "$(cat "$SIDEBAR")" > "$SIDEBAR"
  fi
else
  echo "   -> $SIDEBAR not found (skipping; add include manually if needed)."
fi

echo "==> 3) Importer command (multi-JSON sources with normalization)"
cat > "$IMPCMD" <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use App\Models\Country;
use App\Models\CountryMcc;
use App\Models\Network;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--fresh}';
    protected $description = 'Import countries (MCC) and networks (MCC-MNC) from resilient JSON sources.';

    // [Unverified] Open JSON sources (fallback order)
    private array $urls = [
        'https://raw.githubusercontent.com/opencellid/mcc-mnc-table/master/mcc-mnc-table.json',
        'https://raw.githubusercontent.com/nelsonic/mcc-mnc-list/master/mcc-mnc-list.json',
        'https://raw.githubusercontent.com/musalbas/mcc-mnc-list/master/mcc-mnc-list.json',
    ];

    public function handle() {
        $fresh = (bool) $this->option('fresh');

        // Try remote → local cache
        $raw = null;
        foreach ($this->urls as $u) {
            $this->line("Fetching: $u");
            $ctx = stream_context_create(['http'=>['timeout'=>25],'https'=>['timeout'=>25]]);
            $raw = @file_get_contents($u,false,$ctx);
            if ($raw !== false) break;
        }
        if ($raw===false || $raw===null) {
            $this->warn('Remote fetch failed, trying local cache …');
            $local = storage_path('app/carriers/mcc-mnc-table.json');
            if (is_file($local)) $raw = file_get_contents($local);
        }
        if (!$raw) { $this->error('No carrier data available.'); return self::FAILURE; }

        $json = json_decode($raw, true);
        if (!is_array($json)) { $this->error('Invalid JSON payload'); return self::FAILURE; }

        // Some sources wrap in "data"
        $rows = isset($json['data']) && is_array($json['data']) ? $json['data'] : $json;

        if ($fresh) {
            $this->warn('Fresh import: truncating tables …');
            DB::transaction(function(){
                DB::table('networks')->delete();
                DB::table('country_mccs')->delete();
                DB::table('countries')->delete();
            });
        }

        $countriesAdded=0; $mccLinks=0; $networksAdded=0;
        $cacheByIso=[]; $cacheByName=[];

        $norm = function(array $r) {
            // Try multiple key names across sources
            $mcc = $r['mcc'] ?? ($r['mobile_country_code'] ?? null);
            $mnc = $r['mnc'] ?? ($r['mobile_network_code'] ?? null);
            $country = $r['country'] ?? ($r['country_name'] ?? null);
            $iso2 = $r['iso'] ?? ($r['iso2'] ?? ($r['country_code'] ?? null));
            $brand = $r['brand'] ?? ($r['operator'] ?? ($r['network'] ?? null));

            if ($mcc===null || $mnc===null) return null;
            $mcc = preg_replace('/\D/','',strval($mcc));
            $mnc = preg_replace('/\D/','',strval($mnc));
            if ($mcc==='' || $mnc==='') return null;
            if (strlen($mnc)===1) $mnc = '0'.$mnc; // normalize to at least 2 digits

            $mcc_mnc = $mcc.$mnc;
            $name = trim($brand ?: 'Unknown');
            $country = $country ? trim((string)$country) : null;
            $iso2 = $iso2 ? strtoupper(substr(preg_replace('/[^A-Za-z]/','',$iso2),0,2)) : null;

            return compact('mcc','mnc','mcc_mnc','name','country','iso2');
        };

        DB::transaction(function() use (&$rows,&$norm,&$countriesAdded,&$mccLinks,&$networksAdded,&$cacheByIso,&$cacheByName) {
            foreach ($rows as $r) {
                $n = $norm($r);
                if ($n===null) continue;

                // Country ensure
                $countryId = null;
                if ($n['iso2'] && isset($cacheByIso[$n['iso2']])) {
                    $countryId = $cacheByIso[$n['iso2']];
                } elseif ($n['country'] && isset($cacheByName[$n['country']])) {
                    $countryId = $cacheByName[$n['country']];
                } elseif ($n['country'] || $n['iso2']) {
                    $c = Country::firstOrCreate(
                        $n['iso2'] ? ['iso2'=>$n['iso2']] : ['name'=>$n['country'] ?: 'Unknown'],
                        ['name'=>$n['country'] ?: ($n['iso2'] ?: 'Unknown'), 'iso2'=>$n['iso2']]
                    );
                    $countryId = $c->id;
                    $cacheByName[$c->name] = $c->id;
                    if ($c->iso2) $cacheByIso[$c->iso2] = $c->id;
                    $countriesAdded++;
                }

                // MCC → Country (unique MCC)
                if ($countryId && $n['mcc']) {
                    if (!CountryMcc::where('mcc',$n['mcc'])->exists()) {
                        CountryMcc::create(['country_id'=>$countryId,'mcc'=>$n['mcc']]);
                        $mccLinks++;
                    }
                }

                // Network upsert
                if ($n['mcc_mnc']) {
                    $net = Network::where('mcc_mnc',$n['mcc_mnc'])->first();
                    if (!$net) {
                        $net = new Network();
                        $net->name = $n['name'];
                        $net->mcc = $n['mcc'];
                        $net->mnc = $n['mnc'];
                        $net->mcc_mnc = $n['mcc_mnc'];
                        $net->country_id = $countryId;
                        $net->save();
                        $networksAdded++;
                    } else {
                        $changed=false;
                        if (!$net->name && $n['name']) { $net->name=$n['name']; $changed=true; }
                        if (!$net->country_id && $countryId) { $net->country_id=$countryId; $changed=true; }
                        if ($changed) $net->save();
                    }
                }
            }
        });

        $this->info("Imported: +$countriesAdded countries, +$mccLinks MCC links, +$networksAdded networks");
        return self::SUCCESS;
    }
}
PHP

echo "==> 4) Console Kernel (ensure commands() loads app/Console/Commands)"
mkdir -p app/Console
if [ ! -f "$KERNEL" ]; then
  cat > "$KERNEL" <<'PHP'
<?php
namespace App\Console;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel {
    protected function schedule(Schedule $schedule): void {}
    protected function commands(): void {
        $this->load(__DIR__.'/Commands');
        if (file_exists(base_path('routes/console.php'))) {
            require base_path('routes/console.php');
        }
    }
}
PHP
else
  php -r '
    $f="app/Console/Kernel.php"; $s=file_get_contents($f);
    if (strpos($s, "this->load(__DIR__.\x27/Commands\x27)")===false) {
      $s=preg_replace("/class\\s+Kernel\\s+extends\\s+ConsoleKernel\\s*\\{/","class Kernel extends ConsoleKernel {\\n    protected function commands(): void {\\n        \$this->load(__DIR__.\x27/Commands\x27);\\n        if (file_exists(base_path(\x27routes/console.php\x27))) { require base_path(\x27routes/console.php\x27); }\\n    }\\n",$s,1);
      file_put_contents($f,$s);
    }
  '
fi

echo "==> 5) Fix storage/bootstrap perms INSIDE container"
$DC exec -T app bash -lc '
  set -e
  mkdir -p storage/app/carriers
  chown -R www-data:www-data storage bootstrap/cache || true
  chmod -R ug+rwX storage bootstrap/cache || true
'

echo "==> 6) Clear caches & warm views"
$DC exec -T app bash -lc '
  set -e
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'

echo "==> 7) Test import (no truncate); check summary after return"
$DC exec -T app bash -lc 'php artisan carriers:import || true'

echo "==> Done. The links should show at the top of the left menu. If dataset looks empty, use the page button “Fresh import”."
