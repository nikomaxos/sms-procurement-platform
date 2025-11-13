#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"
TS="$(date +%Y_%m_%d_%H%M%S)"

echo "==> 1) Migrations"
mkdir -p database/migrations

cat > "database/migrations/${TS}_create_countries_and_networks.php" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
  public function up(): void {
    if (!Schema::hasTable('countries')) {
      Schema::create('countries', function (Blueprint $t) {
        $t->id();
        $t->string('name', 120);
        $t->string('iso2', 2)->nullable()->index();
        $t->timestamps();
      });
    }
    if (!Schema::hasTable('country_mccs')) {
      Schema::create('country_mccs', function (Blueprint $t) {
        $t->id();
        $t->foreignId('country_id')->constrained('countries')->cascadeOnDelete();
        $t->string('mcc', 3)->index();
        $t->timestamps();
        $t->unique(['mcc']);
      });
    }
    if (!Schema::hasTable('networks')) {
      Schema::create('networks', function (Blueprint $t) {
        $t->id();
        $t->string('name', 160);
        $t->string('mcc', 3)->index();
        $t->string('mnc', 3)->index();
        $t->string('mcc_mnc', 6)->unique();
        $t->foreignId('country_id')->nullable()->constrained('countries')->nullOnDelete()->index();
        $t->timestamps();
      });
    }
  }
  public function down(): void {
    Schema::dropIfExists('networks');
    Schema::dropIfExists('country_mccs');
    Schema::dropIfExists('countries');
  }
};
PHP

echo "==> 2) Models"
mkdir -p app/Models

cat > app/Models/Country.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Country extends Model {
  protected $fillable = ['name','iso2'];
  public function mccs(){ return $this->hasMany(CountryMcc::class); }
  public function networks(){ return $this->hasMany(Network::class); }
}
PHP

cat > app/Models/CountryMcc.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class CountryMcc extends Model {
  protected $fillable = ['country_id','mcc'];
  public function country(){ return $this->belongsTo(Country::class); }
}
PHP

cat > app/Models/Network.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Network extends Model {
  protected $fillable=['name','mcc','mnc','mcc_mnc','country_id'];
  public function country(){ return $this->belongsTo(Country::class); }
}
PHP

echo "==> 3) Controllers"
mkdir -p app/Http/Controllers

cat > app/Http/Controllers/CountriesController.php <<'PHP'
<?php
namespace App\Http\Controllers;
use App\Models\Country;
use App\Models\CountryMcc;
use Illuminate\Http\Request;

class CountriesController extends Controller {
  public function __construct(){ $this->middleware('auth'); }

  public function index(Request $r){
    $q = trim((string)$r->get('q',''));
    $mcc = trim((string)$r->get('mcc',''));
    $countries = Country::query()
      ->when($q, fn($x)=>$x->where('name','ilike',"%$q%")->orWhere('iso2','ilike',"%$q%"))
      ->when($mcc, fn($x)=>$x->whereHas('mccs', fn($y)=>$y->where('mcc',$mcc)))
      ->with(['mccs'])
      ->orderBy('name')
      ->paginate(20)
      ->withQueryString();
    return view('countries.index', compact('countries','q','mcc'));
  }

  public function create(){ return view('countries.create'); }
  public function store(Request $r){
    $data = $r->validate(['name'=>'required|string|max:120','iso2'=>'nullable|string|size:2','mccs'=>'nullable|string']);
    $c = Country::create(['name'=>$data['name'],'iso2'=> $data['iso2'] ?? null]);
    $this->syncMccs($c, $data['mccs'] ?? '');
    return redirect()->route('countries.index')->with('status','Country created.');
  }
  public function edit(Country $country){
    $mccs = $country->mccs()->pluck('mcc')->implode(', ');
    return view('countries.edit', compact('country','mccs'));
  }
  public function update(Request $r, Country $country){
    $data = $r->validate(['name'=>'required|string|max:120','iso2'=>'nullable|string|size:2','mccs'=>'nullable|string']);
    $country->update(['name'=>$data['name'],'iso2'=>$data['iso2'] ?? null]);
    $this->syncMccs($country, $data['mccs'] ?? '');
    return redirect()->route('countries.index', ['_expand'=>$country->id])->with('status','Country updated.');
  }
  public function destroy(Country $country){
    $country->delete();
    return back()->with('status','Country deleted.');
  }
  public function lookup(Request $r){
    $q = trim((string)$r->get('q',''));
    $items = Country::query()
      ->when($q, fn($x)=>$x->where('name','ilike',"%$q%")->orWhere('iso2','ilike',"%$q%")
         ->orWhereHas('mccs', fn($y)=>$y->where('mcc','ilike',"%$q%")))
      ->with('mccs')->orderBy('name')->limit(20)->get()
      ->map(fn($c)=>['id'=>$c->id,'name'=>$c->name,'iso2'=>$c->iso2,'mccs'=>$c->mccs->pluck('mcc')->implode(', ')]);
    return response()->json($items);
  }
  private function syncMccs(Country $c, string $list){
    $want = collect(preg_split('/[\s,;]+/', $list, -1, PREG_SPLIT_NO_EMPTY))
      ->map(fn($x)=>substr(preg_replace('/\D/','',$x),0,3))
      ->filter()->unique()->values();
    $c->mccs()->delete();
    foreach ($want as $m) $c->mccs()->create(['mcc'=>$m]);
  }
}
PHP

cat > app/Http/Controllers/NetworksController.php <<'PHP'
<?php
namespace App\Http\Controllers;
use App\Models\Network;
use App\Models\Country;
use Illuminate\Http\Request;

class NetworksController extends Controller {
  public function __construct(){ $this->middleware('auth'); }

  public function index(Request $r){
    $q = trim((string)$r->get('q',''));
    $mcc = trim((string)$r->get('mcc',''));
    $mnc = trim((string)$r->get('mnc',''));
    $country = trim((string)$r->get('country',''));
    $networks = Network::query()
      ->when($q, fn($x)=>$x->where('name','ilike',"%$q%"))
      ->when($mcc, fn($x)=>$x->where('mcc',$mcc))
      ->when($mnc, fn($x)=>$x->where('mnc',$mnc))
      ->when($country, fn($x)=>$x->whereHas('country', fn($y)=>$y->where('name','ilike',"%$country%")->orWhere('iso2','ilike',"%$country%")))
      ->with('country')
      ->orderBy('mcc')->orderBy('mnc')
      ->paginate(25)->withQueryString();
    return view('networks.index', compact('networks','q','mcc','mnc','country'));
  }

  public function create(){
    $countries = Country::orderBy('name')->get();
    return view('networks.create', compact('countries'));
  }
  public function store(Request $r){
    $data = $r->validate([
      'name'=>'required|string|max:160',
      'mcc'=>'required|string|size:3',
      'mnc'=>'required|string|min:2|max:3',
      'country_id'=>'nullable|exists:countries,id'
    ]);
    $mnc = str_pad($data['mnc'], 2, '0', STR_PAD_LEFT);
    $mcc_mnc = $data['mcc'].$mnc;
    Network::create(['name'=>$data['name'],'mcc'=>$data['mcc'],'mnc'=>$mnc,'mcc_mnc'=>$mcc_mnc,'country_id'=>$data['country_id'] ?? null]);
    return redirect()->route('networks.index')->with('status','Network created.');
  }
  public function edit(Network $network){
    $countries = Country::orderBy('name')->get();
    return view('networks.edit', compact('network','countries'));
  }
  public function update(Request $r, Network $network){
    $data = $r->validate([
      'name'=>'required|string|max:160',
      'mcc'=>'required|string|size:3',
      'mnc'=>'required|string|min:2|max:3',
      'country_id'=>'nullable|exists:countries,id'
    ]);
    $mnc = str_pad($data['mnc'], 2, '0', STR_PAD_LEFT);
    $network->update(['name'=>$data['name'],'mcc'=>$data['mcc'],'mnc'=>$mnc,'mcc_mnc'=>$data['mcc'].$mnc,'country_id'=>$data['country_id'] ?? null]);
    return redirect()->route('networks.index')->with('status','Network updated.');
  }
  public function destroy(Network $network){
    $network->delete();
    return back()->with('status','Network deleted.');
  }
}
PHP

echo "==> 4) Views"
mkdir -p resources/views/countries resources/views/networks

# Countries index
cat > resources/views/countries/index.blade.php <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
  <h2 class="font-semibold text-xl text-gray-800 mb-4">Countries</h2>

  <form method="GET" class="mb-4 grid grid-cols-1 md:grid-cols-4 gap-3">
    <input name="q" value="{{ $q }}" placeholder="Search name / ISO" class="rounded border px-3 py-2">
    <input name="mcc" value="{{ $mcc }}" placeholder="Filter MCC (e.g. 310)" class="rounded border px-3 py-2">
    <button class="rounded bg-blue-600 px-4 py-2 text-white">Filter</button>
    <a href="{{ route('countries.create') }}" class="rounded bg-gray-700 px-4 py-2 text-white text-center">Add Country</a>
  </form>

  @if (session('status'))
    <div class="mb-3 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm">{{ session('status') }}</div>
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

# Countries create/edit
cat > resources/views/countries/create.blade.php <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="py-6 max-w-2xl mx-auto px-4">
  <h2 class="font-semibold text-xl text-gray-800 mb-4">Add Country</h2>
  <form method="POST" action="{{ route('countries.store') }}" class="space-y-4">
    @csrf
    <div><label class="block text-sm">Name</label><input name="name" class="w-full rounded border px-3 py-2"></div>
    <div><label class="block text-sm">ISO2 (optional)</label><input name="iso2" maxlength="2" class="w-full rounded border px-3 py-2"></div>
    <div><label class="block text-sm">MCCs (comma separated)</label><input name="mccs" class="w-full rounded border px-3 py-2" placeholder="310, 311, 312"></div>
    <div class="flex gap-2">
      <button class="rounded bg-blue-600 px-4 py-2 text-white">Save</button>
      <a href="{{ route('countries.index') }}" class="rounded bg-gray-700 px-4 py-2 text-white">Cancel</a>
    </div>
  </form>
</div>
@endsection
BLADE

cat > resources/views/countries/edit.blade.php <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="py-6 max-w-2xl mx-auto px-4">
  <h2 class="font-semibold text-xl text-gray-800 mb-4">Edit Country</h2>
  <form method="POST" action="{{ route('countries.update', $country) }}" class="space-y-4">
    @csrf @method('PUT')
    <div><label class="block text-sm">Name</label><input name="name" class="w-full rounded border px-3 py-2" value="{{ $country->name }}"></div>
    <div><label class="block text-sm">ISO2 (optional)</label><input name="iso2" maxlength="2" class="w-full rounded border px-3 py-2" value="{{ $country->iso2 }}"></div>
    <div><label class="block text-sm">MCCs (comma separated)</label><input name="mccs" class="w-full rounded border px-3 py-2" value="{{ $mccs }}"></div>
    <div class="flex gap-2">
      <button class="rounded bg-blue-600 px-4 py-2 text-white">Save</button>
      <a href="{{ route('countries.index') }}" class="rounded bg-gray-700 px-4 py-2 text-white">Back</a>
    </div>
  </form>
</div>
@endsection
BLADE

# Networks index
cat > resources/views/networks/index.blade.php <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
  <h2 class="font-semibold text-xl text-gray-800 mb-4">Networks</h2>

  <form method="GET" class="mb-4 grid grid-cols-1 md:grid-cols-6 gap-3">
    <input name="q" value="{{ $q }}" placeholder="Search name" class="rounded border px-3 py-2">
    <input name="mcc" value="{{ $mcc }}" placeholder="MCC" class="rounded border px-3 py-2">
    <input name="mnc" value="{{ $mnc }}" placeholder="MNC" class="rounded border px-3 py-2">
    <input name="country" value="{{ $country }}" placeholder="Country name / ISO" class="rounded border px-3 py-2">
    <button class="rounded bg-blue-600 px-4 py-2 text-white">Filter</button>
    <a href="{{ route('networks.create') }}" class="rounded bg-gray-700 px-4 py-2 text-white text-center">Add Network</a>
  </form>

  @if (session('status'))
    <div class="mb-3 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm">{{ session('status') }}</div>
  @endif

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

# Networks create/edit with datalist type-ahead
cat > resources/views/networks/_form.blade.php <<'BLADE'
@csrf
<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div><label class="block text-sm">Name</label><input name="name" class="w-full rounded border px-3 py-2" value="{{ old('name', $network->name ?? '') }}"></div>
  <div><label class="block text-sm">MCC</label><input name="mcc" maxlength="3" class="w-full rounded border px-3 py-2" value="{{ old('mcc', $network->mcc ?? '') }}"></div>
  <div><label class="block text-sm">MNC</label><input name="mnc" maxlength="3" class="w-full rounded border px-3 py-2" value="{{ old('mnc', $network->mnc ?? '') }}"></div>
  <div>
    <label class="block text-sm">Country</label>
    <input list="countries_datalist" id="country_search" class="w-full rounded border px-3 py-2" placeholder="Type to search"
           value="{{ old('country_name', optional($network->country)->name) }}">
    <input type="hidden" name="country_id" id="country_id" value="{{ old('country_id', $network->country_id ?? '') }}">
    <datalist id="countries_datalist">
      @foreach ($countries as $c)
        <option data-id="{{ $c->id }}" value="{{ $c->name }} ({{ strtoupper($c->iso2 ?? '-') }}, MCCs: {{ $c->mccs()->pluck('mcc')->implode(', ') }})"></option>
      @endforeach
    </datalist>
    <p class="text-xs text-gray-500 mt-1">Pick from the list to bind the country.</p>
  </div>
</div>
<script>
document.addEventListener('DOMContentLoaded', function(){
  const input = document.getElementById('country_search');
  const hidden = document.getElementById('country_id');
  const dl = document.getElementById('countries_datalist');
  input.addEventListener('change', ()=>{
    hidden.value = '';
    for (const opt of dl.options) {
      if (opt.value === input.value) {
        hidden.value = opt.dataset.id || '';
        break;
      }
    }
  });
});
</script>
BLADE

cat > resources/views/networks/create.blade.php <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="py-6 max-w-3xl mx-auto px-4">
  <h2 class="font-semibold text-xl text-gray-800 mb-4">Add Network</h2>
  <form method="POST" action="{{ route('networks.store') }}" class="space-y-4">
    @include('networks._form')
    <div class="flex gap-2">
      <button class="rounded bg-blue-600 px-4 py-2 text-white">Save</button>
      <a href="{{ route('networks.index') }}" class="rounded bg-gray-700 px-4 py-2 text-white">Cancel</a>
    </div>
  </form>
</div>
@endsection
BLADE

cat > resources/views/networks/edit.blade.php <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="py-6 max-w-3xl mx-auto px-4">
  <h2 class="font-semibold text-xl text-gray-800 mb-4">Edit Network</h2>
  <form method="POST" action="{{ route('networks.update',$network) }}" class="space-y-4">
    @method('PUT')
    @include('networks._form')
    <div class="flex gap-2">
      <button class="rounded bg-blue-600 px-4 py-2 text-white">Save</button>
      <a href="{{ route('networks.index') }}" class="rounded bg-gray-700 px-4 py-2 text-white">Back</a>
    </div>
  </form>
</div>
@endsection
BLADE

echo "==> 5) Routes"
ROUTES="routes/web.php"
cp -a "$ROUTES" "$ROUTES.bak.$TS"
php <<'PHP'
<?php
$f="routes/web.php"; $s=file_get_contents($f);
$block = <<<'BLK'

// === Countries & Networks (top-level) ===
Route::middleware(["auth"])->group(function () {
    Route::get("/countries", [\App\Http\Controllers\CountriesController::class, "index"])->name("countries.index");
    Route::get("/countries/create", [\App\Http\Controllers\CountriesController::class, "create"])->name("countries.create");
    Route::post("/countries", [\App\Http\Controllers\CountriesController::class, "store"])->name("countries.store");
    Route::get("/countries/{country}/edit", [\App\Http\Controllers\CountriesController::class, "edit"])->name("countries.edit");
    Route::put("/countries/{country}", [\App\Http\Controllers\CountriesController::class, "update"])->name("countries.update");
    Route::delete("/countries/{country}", [\App\Http\Controllers\CountriesController::class, "destroy"])->name("countries.destroy");
    Route::get("/countries/lookup", [\App\Http\Controllers\CountriesController::class, "lookup"])->name("countries.lookup");

    Route::get("/networks", [\App\Http\Controllers\NetworksController::class, "index"])->name("networks.index");
    Route::get("/networks/create", [\App\Http\Controllers\NetworksController::class, "create"])->name("networks.create");
    Route::post("/networks", [\App\Http\Controllers\NetworksController::class, "store"])->name("networks.store");
    Route::get("/networks/{network}/edit", [\App\Http\Controllers\NetworksController::class, "edit"])->name("networks.edit");
    Route::put("/networks/{network}", [\App\Http\Controllers\NetworksController::class, "update"])->name("networks.update");
    Route::delete("/networks/{network}", [\App\Http\Controllers\NetworksController::class, "destroy"])->name("networks.destroy");
});
BLK;
if (strpos($s, 'Countries & Networks (top-level)') === false) {
  $s .= "\n".$block."\n";
  file_put_contents($f, $s);
}
PHP

echo "==> 6) (Optional) Sidebar links if partial exists"
SIDEBAR="resources/views/partials/sidebar.blade.php"
if [ -f "$SIDEBAR" ]; then
  cp -a "$SIDEBAR" "$SIDEBAR.bak.$TS"
  if ! grep -q "route('countries.index')" "$SIDEBAR"; then
    printf '\n<a href="{{ route('\''countries.index'\'') }}" class="block rounded-lg border p-3 bg-white hover:bg-gray-50 mt-2">Countries</a>\n' >> "$SIDEBAR"
  fi
  if ! grep -q "route('networks.index')" "$SIDEBAR"; then
    printf '<a href="{{ route('\''networks.index'\'') }}" class="block rounded-lg border p-3 bg-white hover:bg-gray-50 mt-2">Networks</a>\n' >> "$SIDEBAR"
  fi
fi

echo "==> 7) Importer command (AOSP)"
mkdir -p app/Console/Commands
cat > app/Console/Commands/ImportCarriers.php <<'PHP'
<?php
namespace App\Console\Commands;
use Illuminate\Console\Command;
use App\Models\Country;
use App\Models\CountryMcc;
use App\Models\Network;

class ImportCarriers extends Command {
  protected $signature = 'carriers:import {--fresh : Truncate before import}';
  protected $description = 'Import countries (MCC) and networks (MCC-MNC) from Google AOSP sources';

  public function handle(){
    if ($this->option('fresh')) {
      \DB::statement('TRUNCATE networks RESTART IDENTITY CASCADE');
      \DB::statement('TRUNCATE country_mccs RESTART IDENTITY CASCADE');
      \DB::statement('TRUNCATE countries RESTART IDENTITY CASCADE');
    }

    $get = function(string $url){
      $ctx = stream_context_create(['http'=>['timeout'=>30],'https'=>['timeout'=>30]]);
      $raw = @file_get_contents($url,false,$ctx);
      if ($raw===false) throw new \RuntimeException("Fetch failed: $url");
      $dec = base64_decode($raw, true);
      return $dec!==false ? $dec : $raw;
    };

    // 1) Countries + MCCs
    $mccUrl = 'https://android.googlesource.com/platform/frameworks/opt/telephony/+/refs/heads/master/src/java/com/android/internal/telephony/MccTable.java?format=TEXT';
    $this->info("Download MCC table...");
    $mccTxt = $get($mccUrl);
    preg_match_all('/MccEntry\((\d{3}),\s*"(\w{2})"\s*,\s*\d+\)\);\s*\/\/\s*([^\r\n]+)/', $mccTxt, $mm, PREG_SET_ORDER);
    $n = 0;
    foreach ($mm as $m) {
      $mcc = $m[1]; $iso = strtolower($m[2]); $name = trim($m[3]);
      $c = Country::firstOrCreate(['iso2'=>$iso], ['name'=>$name ?: strtoupper($iso)]);
      CountryMcc::firstOrCreate(['mcc'=>$mcc], ['country_id'=>$c->id]);
      $n++;
    }
    $this->info("Countries imported: $n");

    // 2) Networks
    $carUrl = 'https://android.googlesource.com/platform/packages/providers/TelephonyProvider/+/master/assets/carrier_list.textpb?format=TEXT';
    $this->info("Download carrier list...");
    $carTxt = $get($carUrl);
    $blocks = preg_split("/\n(?=\s*(carriers?|carrier)\s*\{)/", $carTxt);
    $imported = 0;
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
    $this->info("Done.");
    return self::SUCCESS;
  }
}
PHP

echo "==> 8) Register command in Kernel (safe edit)"
php <<'PHP'
<?php
$f='app/Console/Kernel.php';
$s=file_get_contents($f);
if (strpos($s,'ImportCarriers::class')===false) {
  $s=preg_replace('/protected\s+\$commands\s*=\s*\[/', "protected \$commands = [\n        \\App\\Console\\Commands\\ImportCarriers::class,", $s, 1, $count);
  if ($count===0) {
    $s=preg_replace('/class\s+Kernel\s+extends\s+ConsoleKernel\s*\{/', "class Kernel extends ConsoleKernel {\n    protected \$commands = [\\App\\Console\\Commands\\ImportCarriers::class];\n", $s, 1);
  }
  file_put_contents($f,$s);
}
PHP

echo "==> 9) Migrate & cache"
$DC exec -T app bash -lc 'php artisan migrate --force && php artisan optimize:clear && php artisan route:cache && php artisan view:cache'

echo "==> 10) Initial import (AOSP)"
$DC exec -T app bash -lc 'php artisan carriers:import --fresh'

echo "==> Done. Open /countries and /networks"
