#!/usr/bin/env bash
set -Eeuo pipefail

# Import endpoint controller (to run from UI)
mkdir -p app/Http/Controllers
cat > app/Http/Controllers/CarriersImportController.php <<'PHP'
<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

class CarriersImportController extends Controller {
  public function __construct(){ $this->middleware('auth'); }
  public function run(Request $r){
    $code = Artisan::call('carriers:import', ['--fresh' => $r->boolean('fresh',false)]);
    return back()->with('status', "Import finished (code $code).\n".Artisan::output());
  }
}
PHP

# CountriesController lookup() (typeahead)
php -r '
$f="app/Http/Controllers/CountriesController.php";
if(file_exists($f)){
  $s=file_get_contents($f);
  if(strpos($s,"function lookup(")===false){
    $s=preg_replace(
      "/class\\s+CountriesController\\s+extends\\s+Controller\\s*\\{/",
      "class CountriesController extends Controller {\\n    public function lookup(\\\\Illuminate\\\\Http\\\\Request $r){\\n        $q=trim((string)$r->query(\"q\",\"\"));\\n        $rows=\\\\App\\\\Models\\\\Country::when($q,function($qq) use($q){ $qq->where(\"name\",\"ilike\",\"%\".$q.\"%\"); })->orderBy(\"name\")->limit(8)->get([\"id\",\"name\"]);\\n        return response()->json($rows);\\n    }\\n",
      $s,1
    );
    file_put_contents($f,$s);
  }
}
'

# Routes add (idempotent)
if ! grep -q "carriers.import" routes/web.php 2>/dev/null; then
  printf "%s\n" "Route::post('/carriers/import', [\App\Http\Controllers\CarriersImportController::class,'run'])->name('carriers.import');" >> routes/web.php
fi
if ! grep -q "countries.lookup" routes/web.php 2>/dev/null; then
  printf "%s\n" "Route::get('/countries/lookup', [\App\Http\Controllers\CountriesController::class,'lookup'])->name('countries.lookup');" >> routes/web.php
fi

echo "Routes wired."
