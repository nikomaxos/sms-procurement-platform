#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"
TS="$(date +%F_%H-%M-%S)"

echo "==> 0) Ensure dirs"
mkdir -p app/Console/Commands app/Http/Controllers resources/views/{countries,networks,partials} storage/app/carriers

###############################################################################
# 1) Importer command: use musalbas/mcc-mnc-table (JSON primary, CSV fallback)
###############################################################################
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
        $raw = $get($this->jsonUrl);
        if ($raw) {
            $parsed = json_decode($raw,true);
            if (is_array($parsed)) $data = $parsed;
        }
        if (!$data) {
            $csv = $get($this->csvUrl);
            if ($csv) {
                $rows = array_map('str_getcsv', preg_split("/\r\n|\n|\r/", trim($csv)));
                $hdr  = array_map('strtolower', array_shift($rows) ?: []);
                $data = [];
                foreach ($rows as $r) {
                    if (!$r || count($r) < 3) continue;
                    $rec = array_combine($hdr, array_pad($r, count($hdr), null));
                    $data[] = $rec;
                }
            }
        }

        if (!$data) {
            $this->error('No data fetched from musalbas repo. [Unverified]');
            return 1;
        }

        // Normalize records into: country, iso, mcc, mnc, name
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

        if (empty($norm)) {
            $this->error('Fetched dataset but normalization yielded 0 rows. [Unverified]');
            return 2;
        }

        DB::transaction(function() use ($fresh, $norm) {
            if ($fresh) {
                DB::table('networks')->truncate();
                DB::table('country_mccs')->truncate();
                DB::table('countries')->truncate();
            }

            // Build countries & MCCs
            $countryIdByName = [];
            foreach ($norm as $n) {
                $cname = $n['country'];
                if (!isset($countryIdByName[$cname])) {
                    $country = Country::firstOrCreate(
                        ['name' => $cname],
                        ['iso2' => $n['iso'] ?: null]
                    );
                    $countryIdByName[$cname] = $country->id;
                }
            }

            // Assign MCCs to countries (unique MCC across table)
            $seenMcc = [];
            foreach ($norm as $n) {
                $mcc = $n['mcc'];
                if (isset($seenMcc[$mcc])) continue;
                $seenMcc[$mcc] = true;
                $cid = $countryIdByName[$n['country']] ?? null;
                if ($cid) {
                    CountryMcc::firstOrCreate(['mcc' => $mcc], ['country_id' => $cid]);
                }
            }

            // Build Networks; link country by MCC
            $countryIdByMcc = CountryMcc::pluck('country_id','mcc')->all();

            foreach ($norm as $n) {
                $mcc = str_pad($n['mcc'], 3, '0', STR_PAD_LEFT);
                $mnc = ltrim($n['mnc']); // store raw in column, but pad for mcc_mnc
                $mncPad = str_pad($mnc, 3, '0', STR_PAD_LEFT); // 2-digit -> 003 style
                $key = $mcc.$mncPad;

                $net = Network::where('mcc_mnc',$key)->first();
                if (!$net) $net = new Network();

                $net->name = $n['name'];
                $net->mcc = $mcc;
                $net->mnc = $mnc; // keep original digits here
                $net->mcc_mnc = $key;
                $net->country_id = $countryIdByMcc[$mcc] ?? null;
                $net->save();
            }
        });

        $cCount = Country::count();
        $mCount = CountryMcc::count();
        $nCount = Network::count();
        $this->info("Imported: Countries={$cCount}, Country-MCCs={$mCount}, Networks={$nCount}");
        return 0;
    }
}
PHP

###############################################################################
# 2) Controller action to run import from the UI (button) with log flash
###############################################################################
cat > app/Http/Controllers/CarriersImportController.php <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

class CarriersImportController extends Controller {
    public function __construct() { $this->middleware('auth'); }

    public function run(Request $request) {
        $fresh = $request->boolean('fresh', false);
        $code = Artisan::call('carriers:import', ['--fresh' => $fresh]);
        $out  = Artisan::output();
        return back()->with('status', "Import finished (code $code).\n".$out);
    }
}
PHP

###############################################################################
# 3) Ensure Console Kernel loads commands (idempotent)
###############################################################################
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
# 4) Routes: add import endpoints (once)
###############################################################################
ROUTES="routes/web.php"
touch "$ROUTES"
cp -a "$ROUTES" "$ROUTES.bak.$TS"
php -r '
$f = "routes/web.php";
$s = file_get_contents($f);
if(strpos($s,"CarriersImportController")===false){
  $s = preg_replace("/^<\?php\s*/","<?php\nuse App\\\Http\\\Controllers\\\CarriersImportController;\n",$s,1);
}
if(strpos($s,"carriers.import")===false){
  $s .= "\nRoute::post(\"/carriers/import\", [CarriersImportController::class, \"run\"])->name(\"carriers.import\");\n";
}
file_put_contents($f,$s);
'

###############################################################################
# 5) Fix nav: single placement, nested with main menu, above Settings
###############################################################################
SIDEBAR="resources/views/partials/sidebar.blade.php"
if [ -f "$SIDEBAR" ]; then
  cp -a "$SIDEBAR" "$SIDEBAR.bak.$TS"
  # Remove any existing Countries/Networks duplicates
  perl -0777 -i -pe "s#\\s*<a[^>]*route\\('countries.index'\\)[\\s\\S]*?</a>\\s*##gi" "$SIDEBAR"
  perl -0777 -i -pe "s#\\s*<a[^>]*route\\('networks.index'\\)[\\s\\S]*?</a>\\s*##gi" "$SIDEBAR"

  # Insert a small group right before first Settings link
  perl -0777 -i -pe '
    my $grp = qq{
      <div class="mt-2">
        <a href="{{ route(\'countries.index\') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
          <span class="material-icons text-sm">public</span><span>Countries</span>
        </a>
        <a href="{{ route(\'networks.index\') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
          <span class="material-icons text-sm">cell_tower</span><span>Networks</span>
        </a>
      </div>
    };
    s{(\s*<a\s+href\s*=\s*\"{{\s*route\(\s*'settings\.[^']+'\s*\)\s*}}\")}{$grp$1}i;
  ' "$SIDEBAR" || true
fi

###############################################################################
# 6) Make buttons visible & add timestamps in Countries/Networks views
###############################################################################
# Countries index
CVI="resources/views/countries/index.blade.php"
if [ -f "$CVI" ]; then
  cp -a "$CVI" "$CVI.bak.$TS"
fi
cat > "$CVI" <<'BLADE'
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
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700" onclick="return confirm('Full refresh will truncate and re-import. Continue?')">Fresh import</button>
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
            <td class="px-3 py-2">
              @foreach(($c->mccs ?? []) as $mcc) <span class="inline-block rounded bg-gray-100 px-2 py-0.5 mr-1">{{ $mcc->mcc }}</span> @endforeach
            </td>
            <td class="px-3 py-2">{{ optional($c->created_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2">{{ optional($c->updated_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2 text-right">
              <a href="{{ route('countries.edit',$c) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
            </td>
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
NVI="resources/views/networks/index.blade.php"
if [ -f "$NVI" ]; then
  cp -a "$NVI" "$NVI.bak.$TS"
fi
cat > "$NVI" <<'BLADE'
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
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700" onclick="return confirm('Full refresh will truncate and re-import. Continue?')">Fresh import</button>
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
            <td class="px-3 py-2 text-right">
              <a href="{{ route('networks.edit',$n) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
            </td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $networks->withQueryString()->links() }}</div>
  </div>
</x-app-layout>
BLADE

# Network form partial (ensure $network exists and country typeahead remains)
NF="resources/views/networks/_form.blade.php"
cat > "$NF" <<'BLADE'
@php
  /** @var \App\Models\Network $network */
@endphp
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
    <input name="country_lookup" id="country_lookup" placeholder="Type to search…" class="mt-1 w-full rounded border px-3 py-2" autocomplete="off" value="{{ old('country_lookup', optional($network->country)->name) }}">
    <input type="hidden" name="country_id" id="country_id" value="{{ old('country_id', $network->country_id ?? '') }}">
    <p class="text-xs text-gray-500 mt-1">Start typing to find & link a country (must exist).</p>
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
      const q = inp.value.trim();
      if (!q) return;
      const res = await fetch(`{{ url('/countries/lookup?q=') }}`+encodeURIComponent(q));
      const items = await res.json();
      if (!Array.isArray(items) || !items.length) return;
      const pick = items[0];
      inp.value = pick.name;
      hid.value = pick.id;
    }, 250);
  });
});
</script>
BLADE

# Network create/edit pages
NC="resources/views/networks/create.blade.php"
cat > "$NC" <<'BLADE'
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

NE="resources/views/networks/edit.blade.php"
cat > "$NE" <<'BLADE'
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
# 7) Controller fixes (ensure $network on create, lookup endpoint exists)
###############################################################################
# NetworksController (append safe create method if missing)
php -r '
$F="app/Http/Controllers/NetworksController.php";
if(!file_exists($F)){ exit(0); }
$s=file_get_contents($F);
if(strpos($s,"public function create(")===false){
  $s=preg_replace("/class\\s+NetworksController\\s+extends\\s+Controller\\s*\\{/",
    "class NetworksController extends Controller {\n    public function create(){ \$countries=\\App\\Models\\Country::orderBy(\"name\")->get(); \$network=new \\App\\Models\\Network(); return view(\"networks.create\", compact(\"network\",\"countries\")); }\n",
    $s,1);
  file_put_contents($F,$s);
}
'

# CountriesController: lightweight lookup for typeahead
php -r '
$F="app/Http/Controllers/CountriesController.php";
if(!file_exists($F)) { exit(0); }
$s=file_get_contents($F);
if(strpos($s,"lookup(")===false){
  $s=preg_replace("/class\\s+CountriesController\\s+extends\\s+Controller\\s*\\{/",
    "class CountriesController extends Controller {\n    public function lookup(\\Illuminate\\Http\\Request \$r){ \$q=trim((string)\$r->query(\"q\",\"\")); \$rows=\\App\\Models\\Country::when(\$q,function(\$qq) use(\$q){ \$qq->where(\"name\",\"ilike\",\"%\".\$q.\"%\"); })->orderBy(\"name\")->limit(8)->get([\"id\",\"name\"]); return response()->json(\$rows); }\n",
    $s,1);
  file_put_contents($F,$s);
}
'

# Routes for lookup (once)
php -r '
$f="routes/web.php"; $s=file_get_contents($f);
if(strpos($s,"countries.lookup")===false){
  $s .= "\nRoute::get(\"/countries/lookup\", [\\App\\Http\\Controllers\\CountriesController::class, \"lookup\"])->name(\"countries.lookup\");\n";
  file_put_contents($f,$s);
}
'

###############################################################################
# 8) Storage/bootstrap perms inside container (to avoid Blade write errors)
###############################################################################
$DC exec -T app bash -lc 'mkdir -p storage/app/carriers && chmod -R ug+rwX storage bootstrap/cache || chmod -R 777 storage bootstrap/cache' || true

###############################################################################
# 9) Optimize caches
###############################################################################
$DC exec -T app bash -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache' || true

echo "==> Done. In Countries/Networks pages, use “Update from source” or “Fresh import”. Nav shows once above Settings; buttons visible; create Network fixed; timestamps added."
