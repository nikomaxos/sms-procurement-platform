#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"
TS="$(date +%F_%H-%M-%S)"

echo "==> 0) Ensure dirs"
mkdir -p app/Console/Commands app/Http/Controllers resources/views/{countries,networks,partials}

###############################################################################
# 1) FIX PERMISSIONS for Blade caches (inside container)
###############################################################################
echo "==> 1) Fix storage/bootstrap perms inside container"
$DC exec -T app sh -lc '
  set -e
  mkdir -p storage/framework/{cache,sessions,views} storage/app/carriers bootstrap/cache
  # Try safest first; if chown not allowed, chmod fallback
  (chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true)
  (chgrp -R www-data storage bootstrap/cache 2>/dev/null || true)
  chmod -R ug+rwX storage bootstrap/cache || chmod -R 777 storage bootstrap/cache
'

###############################################################################
# 2) Importer command: musalbas/mcc-mnc-table (JSON → CSV fallback)
###############################################################################
echo "==> 2) Importer command (musalbas)"
cat > app/Console/Commands/ImportCarriers.php <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use App\Models\Country;
use App\Models\CountryMcc;
use App\Models\Network;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--fresh : Truncate and re-import all}';
    protected $description = 'Import Countries (MCC) and Networks (MCC/MNC) from musalbas/mcc-mnc-table';

    private string $jsonUrl = 'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json';
    private string $csvUrl  = 'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.csv';

    public function handle(): int {
        $fresh = (bool)$this->option('fresh');

        $get = function (string $url): ?string {
            $ctx = stream_context_create(['http'=>['timeout'=>30],'https'=>['timeout'=>30]]);
            $raw = @file_get_contents($url,false,$ctx);
            return $raw === false ? null : $raw;
        };

        $data = null;
        if ($raw = $get($this->jsonUrl)) {
            $parsed = json_decode($raw,true);
            if (is_array($parsed)) $data = $parsed;
        }
        if (!$data && ($csv = $get($this->csvUrl))) {
            $rows = array_map('str_getcsv', preg_split("/\r\n|\n|\r/", trim($csv)));
            $hdr  = array_map('strtolower', array_shift($rows) ?: []);
            $data = [];
            foreach ($rows as $r) {
                if (!$r || count($r) < 3) continue;
                $rec = array_combine($hdr, array_pad($r, count($hdr), null));
                $data[] = $rec;
            }
        }
        if (!$data) { $this->error('No data fetched from musalbas repo.'); return 1; }

        $norm = [];
        foreach ($data as $row) {
            $mcc = trim((string)($row['mcc'] ?? ''));
            $mnc = trim((string)($row['mnc'] ?? ''));
            $country = trim((string)($row['country'] ?? ($row['country_name'] ?? '')));
            $iso = strtolower(trim((string)($row['iso'] ?? ($row['iso2'] ?? ''))));
            $brand = trim((string)($row['brand'] ?? ''));
            $oper  = trim((string)($row['operator'] ?? ($row['network'] ?? '')));
            $name  = $brand !== '' ? $brand : ($oper !== '' ? $oper : 'Unknown');
            if ($mcc === '' || $mnc === '' || $country === '') continue;
            $norm[] = compact('country','iso','mcc','mnc','name');
        }
        if (!$norm) { $this->error('Dataset normalized to 0 rows.'); return 2; }

        DB::transaction(function() use ($fresh, $norm) {
            if ($fresh) {
                DB::table('networks')->truncate();
                DB::table('country_mccs')->truncate();
                DB::table('countries')->truncate();
            }

            $countryIdByName = [];
            foreach ($norm as $n) {
                if (!isset($countryIdByName[$n['country']])) {
                    $country = Country::firstOrCreate(
                        ['name' => $n['country']],
                        ['iso2' => $n['iso'] ?: null]
                    );
                    $countryIdByName[$n['country']] = $country->id;
                }
            }

            $seenMcc = [];
            foreach ($norm as $n) {
                if (isset($seenMcc[$n['mcc']])) continue;
                $seenMcc[$n['mcc']] = true;
                $cid = $countryIdByName[$n['country']] ?? null;
                if ($cid) CountryMcc::firstOrCreate(['mcc' => $n['mcc']], ['country_id' => $cid]);
            }

            $countryIdByMcc = CountryMcc::pluck('country_id','mcc')->all();
            foreach ($norm as $n) {
                $mcc = str_pad($n['mcc'], 3, '0', STR_PAD_LEFT);
                $mnc = ltrim($n['mnc']);
                $mncPad = str_pad($mnc, 3, '0', STR_PAD_LEFT);
                $key = $mcc.$mncPad;

                $net = Network::firstOrNew(['mcc_mnc' => $key]);
                $net->name = $n['name'];
                $net->mcc = $mcc;
                $net->mnc = $mnc;           // raw digits
                $net->country_id = $countryIdByMcc[$mcc] ?? null;
                $net->save();
            }
        });

        $this->info("Imported: Countries=".Country::count().", Country-MCCs=".CountryMcc::count().", Networks=".Network::count());
        return 0;
    }
}
PHP

###############################################################################
# 3) Console Kernel loads commands
###############################################################################
echo "==> 3) Console Kernel"
mkdir -p app/Console
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

###############################################################################
# 4) Import endpoint (UI button)
###############################################################################
echo "==> 4) Import endpoint"
cat > app/Http/Controllers/CarriersImportController.php <<'PHP'
<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

class CarriersImportController extends Controller {
  public function __construct(){ $this->middleware('auth'); }
  public function run(Request $r){
    $code = \Artisan::call('carriers:import', ['--fresh' => $r->boolean('fresh',false)]);
    return back()->with('status', "Import finished (code $code).\n".\Artisan::output());
  }
}
PHP

ROUTES="routes/web.php"
touch "$ROUTES"; cp -a "$ROUTES" "$ROUTES.bak.$TS"
php -r '
$f="routes/web.php"; $s=file_get_contents($f);
if(strpos($s,"CarriersImportController")===false){
  $s=preg_replace("/^<\?php\s*/","<?php\nuse App\\\\Http\\\\Controllers\\\\CarriersImportController;\n",$s,1);
}
if(strpos($s,"carriers.import")===false){
  $s.="\nRoute::post(\"/carriers/import\", [CarriersImportController::class, \"run\"])->name(\"carriers.import\");\n";
}
file_put_contents($f,$s);
'

###############################################################################
# 5) Views: buttons visible + timestamps + create view fixes
###############################################################################
echo "==> 5) Views"
# Countries index
cat > resources/views/countries/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Countries</h2></x-slot>
  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <form method="GET" class="flex items-center gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Search countries or MCC…" class="rounded border px-3 py-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      </form>
      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-2">
        @csrf
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Update from source</button>
        <input type="hidden" name="fresh" value="1">
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700" onclick="return confirm('Full refresh?')">Fresh import</button>
      </form>
      <a href="{{ route('countries.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Country</a>
    </div>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">ISO2</th>
            <th class="px-3 py-2 text-left">MCCs</th>
            <th class="px-3 py-2 text-left">Created</th>
            <th class="px-3 py-2 text-left">Updated</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($countries as $c)
          <tr class="border-t">
            <td class="px-3 py-2">{{ $c->name }}</td>
            <td class="px-3 py-2">{{ $c->iso2 }}</td>
            <td class="px-3 py-2">@foreach(($c->mccs ?? []) as $m) <span class="inline-block rounded bg-gray-100 px-2 py-0.5 mr-1">{{ $m->mcc }}</span> @endforeach</td>
            <td class="px-3 py-2">{{ optional($c->created_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2">{{ optional($c->updated_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2 text-right"><a href="{{ route('countries.edit',$c) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a></td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $countries->withQueryString()->links() }}</div>
  </div>
</x-app-layout>
BLADE

# Networks index
cat > resources/views/networks/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2></x-slot>
  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <form method="GET" class="flex items-center gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Search networks, MCC, MNC…" class="rounded border px-3 py-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      </form>
      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-2">
        @csrf
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Update from source</button>
        <input type="hidden" name="fresh" value="1">
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700" onclick="return confirm('Full refresh?')">Fresh import</button>
      </form>
      <a href="{{ route('networks.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Network</a>
    </div>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Name</th>
            <th class="px-3 py-2 text-left">MCC</th>
            <th class="px-3 py-2 text-left">MNC</th>
            <th class="px-3 py-2 text-left">MCC-MNC</th>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">Created</th>
            <th class="px-3 py-2 text-left">Updated</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($networks as $n)
          <tr class="border-t">
            <td class="px-3 py-2">{{ $n->name }}</td>
            <td class="px-3 py-2">{{ $n->mcc }}</td>
            <td class="px-3 py-2">{{ $n->mnc }}</td>
            <td class="px-3 py-2">{{ $n->mcc_mnc }}</td>
            <td class="px-3 py-2">{{ optional($n->country)->name }}</td>
            <td class="px-3 py-2">{{ optional($n->created_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2">{{ optional($n->updated_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2 text-right"><a href="{{ route('networks.edit',$n) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a></td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $networks->withQueryString()->links() }}</div>
  </div>
</x-app-layout>
BLADE

# Network form + create/edit pages (ensure $network exists)
cat > resources/views/networks/_form.blade.php <<'BLADE'
@php /** @var \App\Models\Network|null $network */ @endphp
<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
  <div>
    <label class="block text-sm font-medium text-gray-700">Name</label>
    <input name="name" value="{{ old('name', $network->name ?? '') }}" class="mt-1 w-full rounded border px-3 py-2">
  </div>
  <div>
    <label class="block text-sm font-medium text-gray-700">MCC</label>
    <input name="mcc" value="{{ old('mcc', $network->mcc ?? '') }}" class="mt-1 w-full rounded border px-3 py-2">
  </div>
  <div>
    <label class="block text-sm font-medium text-gray-700">MNC</label>
    <input name="mnc" value="{{ old('mnc', $network->mnc ?? '') }}" class="mt-1 w-full rounded border px-3 py-2">
  </div>
  <div class="md:col-span-3">
    <label class="block text-sm font-medium text-gray-700">Country</label>
    <input name="country_lookup" id="country_lookup" placeholder="Type to search…" class="mt-1 w-full rounded border px-3 py-2" autocomplete="off" value="{{ old('country_lookup', optional($network->country ?? null)->name) }}">
    <input type="hidden" name="country_id" id="country_id" value="{{ old('country_id', $network->country_id ?? '') }}">
    <p class="text-xs text-gray-500 mt-1">Type to find & link a country.</p>
  </div>
</div>
<script>
document.addEventListener('DOMContentLoaded', () => {
  const inp = document.getElementById('country_lookup');
  const hid = document.getElementById('country_id');
  if (!inp) return;
  let t=null;
  inp.addEventListener('input', () => {
    clearTimeout(t);
    t=setTimeout(async () => {
      const q = inp.value.trim(); if (!q) return;
      const res = await fetch(`{{ url('/countries/lookup?q=') }}`+encodeURIComponent(q));
      const items = await res.json(); if (!Array.isArray(items) || !items.length) return;
      const pick = items[0]; inp.value = pick.name; hid.value = pick.id;
    }, 250);
  });
});
</script>
BLADE

cat > resources/views/networks/create.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Add Network</h2></x-slot>
  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.store') }}" class="space-y-6">
      @csrf
      @include('networks._form', ['network' => new \App\Models\Network()])
      <div class="flex gap-3">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

cat > resources/views/networks/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2></x-slot>
  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.update', $network) }}" class="space-y-6">
      @csrf @method('PUT')
      @include('networks._form')
      <div class="flex gap-3">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

###############################################################################
# 6) Countries lookup endpoint (typeahead)
###############################################################################
echo "==> 6) Countries lookup endpoint"
php -r '
$F="app/Http/Controllers/CountriesController.php";
if(file_exists($F)){
  $s=file_get_contents($F);
  if(strpos($s,"function lookup(")===false){
    $s=preg_replace("/class\\s+CountriesController\\s+extends\\s+Controller\\s*\\{/",
      "class CountriesController extends Controller {\\n    public function lookup(\\\\Illuminate\\\\Http\\\\Request $r){ $q=trim((string)$r->query(\"q\",\"\")); $rows=\\\\App\\\\Models\\\\Country::when($q,function($qq) use($q){ $qq->where(\"name\",\"ilike\",\"%\".$q.\"%\"); })->orderBy(\"name\")->limit(8)->get([\"id\",\"name\"]); return response()->json($rows); }\\n",
      $s,1);
    file_put_contents($F,$s);
  }
}
'
if ! grep -q "countries.lookup" routes/web.php; then
  echo 'Route::get("/countries/lookup", [\App\Http\Controllers\CountriesController::class, "lookup"])->name("countries.lookup");' >> routes/web.php
fi

###############################################################################
# 7) Sidebar: place Countries/Networks once, above Settings (using partial)
###############################################################################
echo "==> 7) Sidebar placement"
cat > resources/views/partials/countries_networks_links.blade.php <<'BLADE'
<a href="{{ route('countries.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
  <span class="material-icons text-sm">public</span><span>Countries</span>
</a>
<a href="{{ route('networks.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
  <span class="material-icons text-sm">cell_tower</span><span>Networks</span>
</a>
<hr class="my-2 opacity-30" />
BLADE

SIDEBAR="resources/views/partials/sidebar.blade.php"
if [ -f "$SIDEBAR" ]; then
  cp -a "$SIDEBAR" "$SIDEBAR.bak.$TS"
  # remove any previous inline links
  php -r '
  $f="resources/views/partials/sidebar.blade.php"; $s=file_get_contents($f);
  $s=preg_replace("#\\s*<a[^>]*route\\(\\'countries.index\\'\\)[\\s\\S]*?</a>\\s*#i","",$s);
  $s=preg_replace("#\\s*<a[^>]*route\\(\\'networks.index\\'\\)[\\s\\S]*?</a>\\s*#i","",$s);
  if(strpos($s,"partials.countries_networks_links")===false){
    $s=preg_replace("#(\\s*<a\\s+href=\\\"{{\\s*route\\(\\s*\\'settings\\.)#","@include(\'partials.countries_networks_links\')\n\$1",$s,1);
  }
  file_put_contents($f,$s);
  '
fi

###############################################################################
# 8) Rebuild caches
###############################################################################
echo "==> 8) Clear & warm caches"
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "==> Done. If lists are empty, click “Update from source” (or POST /carriers/import)."
