#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

SIDEBAR="resources/views/partials/sidebar.blade.php"
COUN_VIEW="resources/views/countries/index.blade.php"
NET_VIEW="resources/views/networks/index.blade.php"
KERNEL="app/Console/Kernel.php"
IMPCMD="app/Console/Commands/ImportCarriers.php"

echo "==> Ensure folders & perms"
mkdir -p resources/views/partials app/Console/Commands storage/app/carriers
chmod -R u+rwX,g+rwX storage bootstrap/cache || true

echo "==> Sidebar: insert Countries/Networks above Settings"
if [ -f "$SIDEBAR" ]; then
  cp -a "$SIDEBAR" "$SIDEBAR.bak.$(date +%F_%H-%M-%S)"
  # If not already present, inject two items right before the first settings.* link
  perl -0777 -i -pe '
    my $add = qq{\n      <a href="{{ route(\'countries.index\') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">\n        <span class="material-icons text-sm">public</span>\n        <span>Countries</span>\n      </a>\n      <a href="{{ route(\'networks.index\') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">\n        <span class="material-icons text-sm">cell_tower</span>\n        <span>Networks</span>\n      </a>\n};
    if (index($_, "route('countries.index')")==-1 && index($_, "route('networks.index')")==-1) {
      s{(\s*<a\s+href=\"{{\s*route\(\s*'settings\.)}{$add$1}i;
    }
    $_;
  ' "$SIDEBAR" || true
else
  echo "   -> $SIDEBAR not found (skipping visual nav insertion)."
fi

echo "==> Replace importer with multi-source JSON and robust mapping"
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

    // [Unverified] Sources (raw JSON)
    private array $urls = [
        // OpenCelliD mirror
        'https://raw.githubusercontent.com/opencellid/mcc-mnc-table/master/mcc-mnc-table.json',
        // nelsonic
        'https://raw.githubusercontent.com/nelsonic/mcc-mnc-list/master/mcc-mnc-list.json',
        // musalbas
        'https://raw.githubusercontent.com/musalbas/mcc-mnc-list/master/mcc-mnc-list.json',
    ];

    public function handle() {
        $fresh = (bool)$this->option('fresh');

        // Local cache fallback (drop a file here to import offline)
        $local = storage_path('app/carriers/mcc-mnc-table.json');

        $raw = null;
        foreach ($this->urls as $u) {
            $this->line("Fetching: $u");
            $ctx = stream_context_create(['http'=>['timeout'=>25],'https'=>['timeout'=>25]]);
            $raw = @file_get_contents($u,false,$ctx);
            if ($raw !== false) break;
        }
        if ($raw===false || $raw===null) {
            $this->warn('Remote fetch failed, trying local cache …');
            if (is_file($local)) {
                $raw = file_get_contents($local);
            } else {
                $this->error('No data available (remote+local failed).');
                return self::FAILURE;
            }
        }

        $json = json_decode($raw, true);
        if (!is_array($json)) {
            $this->error('Invalid JSON payload.');
            return self::FAILURE;
        }

        if ($fresh) {
            $this->warn('Fresh import: truncating tables …');
            DB::transaction(function(){
                DB::table('networks')->delete();
                DB::table('country_mccs')->delete();
                DB::table('countries')->delete();
            });
        }

        $countriesAdded = 0; $mccLinks = 0; $networksAdded = 0;
        $countryCacheByName = [];
        $countryCacheByIso  = [];

        // Normalize one record to unified shape
        $norm = function(array $r) {
            // Try common keys across sources
            $mcc = $r['mcc'] ?? ($r['mobile_country_code'] ?? null);
            $mnc = $r['mnc'] ?? ($r['mobile_network_code'] ?? null);
            $country = $r['country'] ?? ($r['country_name'] ?? null);
            $iso2 = $r['iso'] ?? ($r['iso2'] ?? ($r['country_code'] ?? null));
            $brand = $r['brand'] ?? ($r['operator'] ?? ($r['network'] ?? null));
            if ($mcc === null || $mnc === null) return null;

            $mcc = trim((string)$mcc);
            $mnc = trim((string)$mnc);
            // Clean digits only
            $mcc = preg_replace('/\D/', '', $mcc ?? '');
            $mnc = preg_replace('/\D/', '', $mnc ?? '');
            if ($mcc === '' || $mnc === '') return null;

            // Keep MNC as 2 or 3 digits if the source provides leading zeros
            if (strlen($mnc) === 1) $mnc = '0'.$mnc; // normalize 1-digit to 2-digit

            $mcc_mnc = $mcc.$mnc; // 5 or 6 chars
            $name = trim((string)($brand ?? 'Unknown'));

            $country = $country ? trim((string)$country) : null;
            $iso2 = $iso2 ? strtoupper(substr(preg_replace('/[^A-Za-z]/','',$iso2),0,2)) : null;

            return compact('mcc','mnc','mcc_mnc','name','country','iso2');
        };

        $rows = $json;
        // Some sources wrap under "data" or similar
        if (isset($rows['data']) && is_array($rows['data'])) $rows = $rows['data'];

        DB::transaction(function() use (&$rows,&$norm,&$countriesAdded,&$mccLinks,&$networksAdded,&$countryCacheByName,&$countryCacheByIso) {
            foreach ($rows as $r) {
                $n = $norm($r);
                if ($n === null) continue;

                // Countries: ensure one row per country name (or ISO)
                $countryId = null;
                if ($n['country'] || $n['iso2']) {
                    $targetName = $n['country'] ?: null;
                    $targetIso  = $n['iso2'] ?: null;

                    if ($targetIso && isset($countryCacheByIso[$targetIso])) {
                        $countryId = $countryCacheByIso[$targetIso];
                    } elseif ($targetName && isset($countryCacheByName[$targetName])) {
                        $countryId = $countryCacheByName[$targetName];
                    } else {
                        // Create country
                        $c = Country::firstOrCreate(
                            $targetIso ? ['iso2'=>$targetIso] : ['name'=>$targetName ?: 'Unknown'],
                            ['name'=>$targetName ?: ($targetIso ?: 'Unknown'), 'iso2'=>$targetIso]
                        );
                        $countryId = $c->id;
                        $countryCacheByName[$c->name] = $c->id;
                        if ($c->iso2) $countryCacheByIso[$c->iso2] = $c->id;
                        $countriesAdded++;
                    }
                }

                // MCC mapping to country (unique mcc)
                if ($countryId && $n['mcc']) {
                    $exists = CountryMcc::where('mcc',$n['mcc'])->exists();
                    if (!$exists) {
                        CountryMcc::create(['country_id'=>$countryId,'mcc'=>$n['mcc']]);
                        $mccLinks++;
                    }
                }

                // Networks
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
                        // Update name/country if empty
                        $changed = false;
                        if (!$net->name && $n['name']) { $net->name = $n['name']; $changed=true; }
                        if (!$net->country_id && $countryId) { $net->country_id = $countryId; $changed=true; }
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

echo "==> Register command in Console Kernel (idempotent)"
mkdir -p "$(dirname "$KERNEL")"
if [ ! -f "$KERNEL" ]; then
  cat > "$KERNEL" <<'PHP'
<?php
namespace App\Console;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel {
    protected $commands = [
        \App\Console\Commands\ImportCarriers::class,
    ];
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
    if (strpos($s,"ImportCarriers::class")===false) {
      if (preg_match("/protected\\s+\\$commands\\s*=\\s*\\[/",$s)) {
        $s=preg_replace("/protected\\s+\\$commands\\s*=\\s*\\[/","protected \$commands = [\n        \\\\App\\\\Console\\\\Commands\\\\ImportCarriers::class,",$s,1);
      } else {
        $s=preg_replace("/class\\s+Kernel\\s+extends\\s+ConsoleKernel\\s*\\{/","class Kernel extends ConsoleKernel {\n    protected \$commands = [\\\\App\\\\Console\\\\Commands\\\\ImportCarriers::class];\n",$s,1);
      }
      file_put_contents($f,$s);
    }'
fi

echo "==> Add import buttons to Countries & Networks pages (top toolbar)"
for V in "$COUN_VIEW" "$NET_VIEW"; do
  if [ -f "$V" ]; then
    cp -a "$V" "$V.bak.$(date +%F_%H-%M-%S)"
    perl -0777 -i -pe '
      if (index($_,"carriers-import-toolbar")==-1) {
        s{(<x-app-layout>\s*<x-slot name="header">[\s\S]*?</x-slot>)}{$1\n  <div class="carriers-import-toolbar max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-4">\n    <form method="POST" action="{{ route(str_contains(request()->path(),\"networks\")?\"networks.import\":\"countries.import\") }}" class="inline">\n      @csrf\n      <button class="rounded bg-blue-600 px-3 py-2 text-white hover:bg-blue-700">Refresh from external</button>\n    </form>\n    <form method="POST" action="{{ route(str_contains(request()->path(),\"networks\")?\"networks.import\":\"countries.import\") }}" class="inline ms-2">\n      @csrf\n      <input type="hidden" name="fresh" value="1">\n      <button class="rounded bg-red-600 px-3 py-2 text-white hover:bg-red-700" onclick="return confirm(\'Fresh import will clear existing data. Proceed?\')">Fresh import</button>\n    </form>\n  </div>\n}i;
      }
      $_;
    ' "$V"
  fi
done

echo "==> Web routes for import endpoints"
perl -0777 -i -pe '
  if (index($_,"countries.import")==-1) {
    s{(\n//\s*Change Password.*?\}\);\s*\n)}{$1

// Countries/Networks import actions
Route::middleware([\"auth\"])->group(function () {
    Route::post(\"/countries/import\", [\\App\\Http\\Controllers\\CountriesController::class, \"import\"])
        ->name(\"countries.import\");
    Route::post(\"/networks/import\", [\\App\\Http\\Controllers\\NetworksController::class, \"import\"])
        ->name(\"networks.import\");
});
}si;
  }
  $_;
' routes/web.php

echo "==> Controller methods to trigger import"
php -r '
  $files=["app/Http/Controllers/CountriesController.php","app/Http/Controllers/NetworksController.php"];
  foreach($files as $f){
    if(!file_exists($f)) continue;
    $s=file_get_contents($f);
    if(strpos($s,"function import(")===false){
      $s=preg_replace(
        "/class\\s+([A-Za-z]+Controller)\\s+extends\\s+Controller\\s*\\{/",
        "class $1 extends Controller {\n    public function import(\\Illuminate\\Http\\Request $request){\\n        \\Artisan::call(\\'carriers:import\\',[\\'--fresh\\'=>$request->boolean(\\'fresh\\')]);\\n        return back()->with(\\'status\\', \\Artisan::output());\\n    }",
        $s,1
      );
      file_put_contents($f,$s);
    }
  }
'

echo "==> Clear & rebuild caches; warm views"
$DC exec -T app bash -lc '
  set -e
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'

echo "==> Test run (no truncate)"
$DC exec -T app bash -lc 'php artisan carriers:import || true'

echo "==> Done. Open /countries and /networks; use the blue toolbar buttons."
