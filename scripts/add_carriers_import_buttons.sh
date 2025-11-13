#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

echo "==> 1) Ensure Console Kernel exists & registers ImportCarriers"
mkdir -p app/Console
if [ ! -f app/Console/Kernel.php ]; then
  cat > app/Console/Kernel.php <<'PHP'
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
  # add the command if not present
  php -r '
    $f="app/Console/Kernel.php";
    $s=file_get_contents($f);
    if(strpos($s,"ImportCarriers::class")===false){
      if(preg_match("/protected\\s+\\$commands\\s*=\\s*\\[/",$s)){
        $s=preg_replace("/protected\\s+\\$commands\\s*=\\s*\\[/","protected \$commands = [\n        \\\\App\\\\Console\\\\Commands\\\\ImportCarriers::class,",$s,1);
      } else {
        $s=preg_replace("/class\\s+Kernel\\s+extends\\s+ConsoleKernel\\s*\\{/","class Kernel extends ConsoleKernel {\n    protected \$commands = [\\\\App\\\\Console\\\\Commands\\\\ImportCarriers::class];\n",$s,1);
      }
      file_put_contents($f,$s);
    }'
fi

echo "==> 2) Make importer resilient (multi-URL + local cache fallback)"
cat > app/Console/Commands/ImportCarriers.php <<'PHP'
<?php
namespace App\Console\Commands;
use Illuminate\Console\Command;
use App\Models\Country;
use App\Models\CountryMcc;
use App\Models\Network;

class ImportCarriers extends Command {
  protected $signature = 'carriers:import {--fresh : Truncate before import}';
  protected $description = 'Import countries (MCC) and networks (MCC-MNC) from AOSP sources, with offline fallback';

  public function handle(){
    if ($this->option('fresh')) {
      \DB::statement('TRUNCATE networks RESTART IDENTITY CASCADE');
      \DB::statement('TRUNCATE country_mccs RESTART IDENTITY CASCADE');
      \DB::statement('TRUNCATE countries RESTART IDENTITY CASCADE');
    }

    $get = function(array $urls, ?string $local = null){
      foreach ($urls as $url) {
        $this->info("Fetch: $url");
        $ctx = stream_context_create(['http'=>['timeout'=>30],'https'=>['timeout'=>30]]);
        $raw = @file_get_contents($url,false,$ctx);
        if ($raw!==false) {
          $dec = base64_decode($raw, true);
          return $dec!==false ? $dec : $raw;
        }
      }
      if ($local && is_file($local)) {
        $this->warn("Using local cache: $local");
        return file_get_contents($local);
      }
      throw new \RuntimeException("Fetch failed for all URLs and no local cache found.");
    };

    // 1) Countries + MCCs (MccTable)
    $mccTxt = $get(
      ['https://android.googlesource.com/platform/frameworks/opt/telephony/+/refs/heads/master/src/java/com/android/internal/telephony/MccTable.java?format=TEXT',
       'https://android.googlesource.com/platform/frameworks/opt/telephony/+/master/src/java/com/android/internal/telephony/MccTable.java?format=TEXT'],
      storage_path('app/carriers/MccTable.java')
    );
    preg_match_all('/MccEntry\((\d{3}),\s*"(\w{2})"\s*,\s*\d+\)\);\s*\/\/\s*([^\r\n]+)/', $mccTxt, $mm, PREG_SET_ORDER);
    $n = 0;
    foreach ($mm as $m) {
      $mcc = $m[1]; $iso = strtolower($m[2]); $name = trim($m[3]);
      $c = Country::firstOrCreate(['iso2'=>$iso], ['name'=>$name ?: strtoupper($iso)]);
      CountryMcc::firstOrCreate(['mcc'=>$mcc], ['country_id'=>$c->id]);
      $n++;
    }
    $this->info("Countries imported/updated: $n");

    // 2) Networks (carrier_list / telephony provider)
    $carTxt = null;
    try {
      $carTxt = $get(
        ['https://android.googlesource.com/platform/packages/providers/TelephonyProvider/+/refs/heads/master/assets/carrier_list.textpb?format=TEXT',
         'https://android.googlesource.com/platform/packages/providers/TelephonyProvider/+/master/assets/carrier_list.textpb?format=TEXT'],
        storage_path('app/carriers/carrier_list.textpb')
      );
    } catch (\Throwable $e) {
      $this->warn("No carrier_list available (offline?). Skipping networks import. ".$e->getMessage());
    }

    $imported = 0;
    if ($carTxt) {
      $blocks = preg_split("/\n(?=\s*(carriers?|carrier)\s*\{)/", $carTxt);
      foreach ($blocks as $b) {
        if (!preg_match('/mccmnc\s*:\s*"([0-9]{5,6})"/', $b)) continue;
        $name = null;
        if (preg_match('/canonical_name\s*:\s*"([^"]+)"/', $b, $m)) $name=$m[1];
        elseif (preg_match('/carrier_name\s*:\s*"([^"]+)"/', $b, $m)) $name=$m[1];
        elseif (preg_match('/name\s*:\s*"([^"]+)"/', $b, $m)) $name=$m[1];
        if (!$name) $name = 'Unknown Carrier';
        preg_match_all('/mccmnc\s*:\s*"([0-9]{5,6})"/', $b, $codes);
        foreach ($codes[1] as $code) {
          $mcc = substr($code,0,3); $mnc = substr($code,3);
          $countryId = optional(\App\Models\CountryMcc::where('mcc',$mcc)->first())->country_id;
          \App\Models\Network::updateOrCreate(
            ['mcc_mnc'=>$mcc.$mnc],
            ['name'=>$name, 'mcc'=>$mcc, 'mnc'=>$mnc, 'country_id'=>$countryId]
          );
          $imported++;
        }
      }
      $this->info("Networks imported/updated: $imported");
    }

    $this->info("Done.");
    return self::SUCCESS;
  }
}
PHP

echo "==> 3) Controller to run import from UI (with log)"
mkdir -p app/Http/Controllers
cat > app/Http/Controllers/CarriersImportController.php <<'PHP'
<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

class CarriersImportController extends Controller {
  public function __construct(){ $this->middleware('auth'); }
  public function run(Request $r){
    $fresh = $r->boolean('fresh');
    try {
      Artisan::call('carriers:import', $fresh ? ['--fresh'=>true] : []);
      $out = Artisan::output();
      // Keep log short in the UI
      $log = trim(mb_strimwidth($out, 0, 2000, "\n..."));
      return back()->with('status', $fresh ? 'Fresh import completed.' : 'Refresh completed.')->with('import_log', $log);
    } catch (\Throwable $e) {
      return back()->with('status', 'Import failed: '.$e->getMessage());
    }
  }
}
PHP

echo "==> 4) Routes for import"
ROUTES="routes/web.php"
cp -a "$ROUTES" "$ROUTES.bak.$(date +%F_%H-%M-%S)"
php -r '
$f="routes/web.php"; $s=file_get_contents($f);
$blk = <<<'BLK'

// === Carriers Import (UI trigger) ===
Route::middleware(["auth"])->post("/carriers/import", [\App\Http\Controllers\CarriersImportController::class, "run"])->name("carriers.import");
BLK;
if (strpos($s,"Carriers Import (UI trigger)")===false) { $s.="\n".$blk."\n"; file_put_contents($f,$s); }
'

echo "==> 5) Inject import toolbar into Countries & Networks views"
for V in resources/views/countries/index.blade.php resources/views/networks/index.blade.php; do
  if [ -f "$V" ]; then
    cp -a "$V" "$V.bak.$(date +%F_%H-%M-%S)"
  fi
done

# Countries view with toolbar & log
cat > resources/views/countries/index.blade.php <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
  <h2 class="font-semibold text-xl text-gray-800 mb-4">Countries</h2>

  <div class="mb-3 flex flex-wrap items-center gap-2">
    <form method="POST" action="{{ route('carriers.import') }}">
      @csrf
      <input type="hidden" name="fresh" value="0">
      <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Refresh from external sources</button>
    </form>
    <form method="POST" action="{{ route('carriers.import') }}">
      @csrf
      <input type="hidden" name="fresh" value="1">
      <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Fresh import (truncate & reimport)</button>
    </form>
  </div>

  @if (session('status'))
    <div class="mb-3 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm">{{ session('status') }}</div>
  @endif
  @if (session('import_log'))
    <pre class="mb-4 rounded border bg-gray-50 p-3 text-xs whitespace-pre-wrap">{{ session('import_log') }}</pre>
  @endif

  <form method="GET" class="mb-4 grid grid-cols-1 md:grid-cols-4 gap-3">
    <input name="q" value="{{ $q }}" placeholder="Search name / ISO" class="rounded border px-3 py-2">
    <input name="mcc" value="{{ $mcc }}" placeholder="Filter MCC (e.g. 310)" class="rounded border px-3 py-2">
    <button class="rounded bg-blue-600 px-4 py-2 text-white">Filter</button>
    <a href="{{ route('countries.create') }}" class="rounded bg-gray-700 px-4 py-2 text-white text-center">Add Country</a>
  </form>

  @if (session('status2'))
    <div class="mb-3 rounded border bg-blue-50 text-blue-800 px-4 py-2 text-sm">{{ session('status2') }}</div>
  @endif

  <div class="space-y-2">
    @foreach ($countries as $c)
      <details {{ request('_expand') == $c->id ? 'open' : '' }} class="rounded border bg-white px-4 py-3">
        <summary class="cursor-pointer flex items-center justify-between">
          <div>
            <span class="font-medium">{{ $c->name }}</span>
            <span class="text-gray-500 text-sm"> — ISO: {{ strtoupper($c->iso2 ?? '-') }}</span>
            <span class="text-gray-500 text-sm"> — MCCs: {{ $c->mccs->pluck('mcc')->implode(', ') ?: '—' }}</span>
          </div>
          <div class="flex gap-2">
            <a href="{{ route('countries.edit',$c) }}" class="text-blue-600 hover:underline text-sm">Edit</a>
            <form method="POST" action="{{ route('countries.destroy',$c) }}" onsubmit="return confirm('Delete country?')">
              @csrf @method('DELETE')
              <button class="text-red-600 hover:underline text-sm">Delete</button>
            </form>
          </div>
        </summary>
        <div class="mt-3">
          <div class="text-sm text-gray-600 mb-2">Linked Networks:</div>
          <div class="overflow-auto">
            <table class="min-w-full text-sm">
              <thead><tr class="text-left">
                <th class="pr-3 py-1">Name</th><th class="pr-3 py-1">MCC</th><th class="pr-3 py-1">MNC</th><th class="pr-3 py-1">MCC-MNC</th>
              </tr></thead>
              <tbody>
              @foreach ($c->networks()->orderBy('mcc')->orderBy('mnc')->limit(200)->get() as $n)
                <tr class="border-t">
                  <td class="pr-3 py-1">{{ $n->name }}</td>
                  <td class="pr-3 py-1">{{ $n->mcc }}</td>
                  <td class="pr-3 py-1">{{ $n->mnc }}</td>
                  <td class="pr-3 py-1">{{ $n->mcc_mnc }}</td>
                </tr>
              @endforeach
              </tbody>
            </table>
          </div>
        </div>
      </details>
    @endforeach
  </div>

  <div class="mt-4">{{ $countries->links() }}</div>
</div>
@endsection
BLADE

# Networks view with toolbar & log
cat > resources/views/networks/index.blade.php <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
  <h2 class="font-semibold text-xl text-gray-800 mb-4">Networks</h2>

  <div class="mb-3 flex flex-wrap items-center gap-2">
    <form method="POST" action="{{ route('carriers.import') }}">
      @csrf
      <input type="hidden" name="fresh" value="0">
      <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Refresh from external sources</button>
    </form>
    <form method="POST" action="{{ route('carriers.import') }}">
      @csrf
      <input type="hidden" name="fresh" value="1">
      <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Fresh import (truncate & reimport)</button>
    </form>
  </div>

  @if (session('status'))
    <div class="mb-3 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm">{{ session('status') }}</div>
  @endif
  @if (session('import_log'))
    <pre class="mb-4 rounded border bg-gray-50 p-3 text-xs whitespace-pre-wrap">{{ session('import_log') }}</pre>
  @endif

  <form method="GET" class="mb-4 grid grid-cols-1 md:grid-cols-6 gap-3">
    <input name="q" value="{{ $q }}" placeholder="Search name" class="rounded border px-3 py-2">
    <input name="mcc" value="{{ $mcc }}" placeholder="MCC" class="rounded border px-3 py-2">
    <input name="mnc" value="{{ $mnc }}" placeholder="MNC" class="rounded border px-3 py-2">
    <input name="country" value="{{ $country }}" placeholder="Country name / ISO" class="rounded border px-3 py-2">
    <button class="rounded bg-blue-600 px-4 py-2 text-white">Filter</button>
    <a href="{{ route('networks.create') }}" class="rounded bg-gray-700 px-4 py-2 text-white text-center">Add Network</a>
  </form>

  <div class="overflow-auto bg-white rounded border">
    <table class="min-w-full text-sm">
      <thead><tr class="text-left">
        <th class="px-3 py-2">Name</th><th class="px-3 py-2">MCC</th><th class="px-3 py-2">MNC</th><th class="px-3 py-2">MCC-MNC</th><th class="px-3 py-2">Country</th><th class="px-3 py-2"></th>
      </tr></thead>
      <tbody>
      @foreach ($networks as $n)
        <tr class="border-t">
          <td class="px-3 py-2">{{ $n->name }}</td>
          <td class="px-3 py-2">{{ $n->mcc }}</td>
          <td class="px-3 py-2">{{ $n->mnc }}</td>
          <td class="px-3 py-2">{{ $n->mcc_mnc }}</td>
          <td class="px-3 py-2">{{ optional($n->country)->name }}</td>
          <td class="px-3 py-2">
            <a href="{{ route('networks.edit',$n) }}" class="text-blue-600 hover:underline">Edit</a>
            <form method="POST" action="{{ route('networks.destroy',$n) }}" class="inline" onsubmit="return confirm('Delete network?')">
              @csrf @method('DELETE')
              <button class="text-red-600 hover:underline ms-2">Delete</button>
            </form>
          </td>
        </tr>
      @endforeach
      </tbody>
    </table>
  </div>

  <div class="mt-4">{{ $networks->links() }}</div>
</div>
@endsection
BLADE

echo "==> 6) Create local cache folder (optional offline files)"
mkdir -p storage/app/carriers

echo "==> 7) Clear caches"
$DC exec -T app bash -lc 'php artisan optimize:clear && php artisan route:cache && php artisan view:cache'

echo "==> Done. Buttons added to /countries and /networks."
