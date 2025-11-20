#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Step4b: CountriesController@update + duplicate-MCC UI handling"

# 1) CountriesController@update (idempotent add/replace)
K=app/Http/Controllers/CountriesController.php
b "$K"
php -r '
$f="app/Http/Controllers/CountriesController.php";
$c=file_get_contents($f);
if(strpos($c,"function update(")===false){
  $c=preg_replace(
    "#(<\?php.*class\s+CountriesController[^{]*\{)#s",
    "$1\n    public function update(\\Illuminate\\Http\\Request \$request, \\App\\Models\\Country \$country) {\n        \$data = \$request->validate([\n            \"name\" => [\"required\",\"string\",\"max:255\"],\n            \"iso2\" => [\"nullable\",\"string\",\"size:2\"],\n        ]);\n        if(isset(\$data[\"iso2\"])) { \$data[\"iso2\"] = strtolower(\$data[\"iso2\"]); }\n        \$country->fill(\$data); \$country->save();\n        return redirect()->route(\"countries.edit\", \$country)->with(\"status\", \"Country updated.\");\n    }\n",
    $c,1
  );
  file_put_contents($f,$c);
}
';

# 2) CountryMccController: store() -> friendly duplicate handling + log panel signals
CMC=app/Http/Controllers/CountryMccController.php
b "$CMC"
cat > "$CMC" <<'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\Country;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CountryMccController extends Controller
{
    public function store(Request $request, Country $country)
    {
        $validated = $request->validate([
            'mcc' => ['required','digits:3'],
        ]);

        $mcc = $validated['mcc']; // keep as 3-char string
        $existing = DB::table('country_mccs')->where('mcc', $mcc)->first();

        // Build log array and flash it so edit.blade.php can render
        $log = session('log', []);

        if ($existing) {
            if ((int)$existing->country_id === (int)$country->id) {
                $log[] = ['level'=>'info', 'msg'=>"MCC $mcc already exists for {$country->name}."];
                return back()->with('log', $log);
            } else {
                $other = Country::find($existing->country_id);
                $otherName = $other ? $other->name : "country_id={$existing->country_id}";
                $log[] = ['level'=>'error', 'msg'=>"MCC $mcc is already assigned to {$otherName}. No changes made."];
                return back()->with('log', $log)->withInput();
            }
        }

        DB::table('country_mccs')->insert([
            'country_id' => $country->id,
            'mcc'        => $mcc,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $log[] = ['level'=>'success', 'msg'=>"MCC $mcc added to {$country->name}."];
        return back()->with('log', $log);
    }

    public function destroy(Country $country, string $mcc)
    {
        $deleted = DB::table('country_mccs')->where(['country_id'=>$country->id, 'mcc'=>$mcc])->delete();
        $log = session('log', []);
        if ($deleted) {
            $log[] = ['level'=>'success','msg'=>"MCC $mcc removed from {$country->name}."];
        } else {
            $log[] = ['level'=>'info','msg'=>"MCC $mcc not found for {$country->name} (nothing to remove)."];
        }
        return back()->with('log',$log);
    }
}
PHP

# 3) Country edit view: show a simple log panel + validation/errors
V=resources/views/countries/edit.blade.php
b "$V"
php -r '
$f="resources/views/countries/edit.blade.php";
$c=file_get_contents($f);
if(strpos($c,"<!-- log-panel -->")===false){
  $panel=<<<BLADE

    <!-- log-panel -->
    @if (session("status"))
      <div class="mb-4 rounded border border-green-200 bg-green-50 p-3 text-green-800">
        {{ session("status") }}
      </div>
    @endif

    @if ($errors->any())
      <div class="mb-4 rounded border border-red-200 bg-red-50 p-3 text-red-800">
        <div class="font-semibold">Validation errors</div>
        <ul class="mt-2 list-disc list-inside">
          @foreach ($errors->all() as $error)
            <li>{{ $error }}</li>
          @endforeach
        </ul>
      </div>
    @endif

    @if (session("log"))
      <div class="mb-4 rounded border bg-gray-50 p-3">
        <div class="font-semibold text-gray-800">Log</div>
        <ul class="mt-2 space-y-1">
          @foreach (session("log") as $entry)
            @php $lvl = $entry["level"] ?? "info"; @endphp
            <li class="@if($lvl === "error") text-red-700 @elseif($lvl === "success") text-green-700 @else text-gray-800 @endif">
              {{ $entry["msg"] ?? "" }}
            </li>
          @endforeach
        </ul>
      </div>
    @endif
BLADE;
  // place panel after opening container div if possible
  $c=preg_replace("#(<div[^>]*class=[\"\\\'].*?\\bcontainer\\b.*?[\"\\\'][^>]*>)#s","$1\n".$panel,$c,1);
  file_put_contents($f,$c);
}
';

# 4) Warm caches
$DC exec -T app sh -lc '
  php -l app/Http/Controllers/CountriesController.php
  php -l app/Http/Controllers/CountryMccController.php
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'
echo "==> Step4b complete."
