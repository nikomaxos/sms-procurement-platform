#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Step4b_v2: countries.update fix + duplicate-MCC UI + flash log"

# 0) Paths
R=routes/web.php
UP=app/Http/Controllers/CountryUpdateProxy.php
CMC=app/Http/Controllers/CountryMccController.php
FLASH=resources/views/components/flash-log.blade.php
VC=resources/views/countries/edit.blade.php

# 1) CountryUpdateProxy (handles PUT /countries/{country})
b "$UP"; mkdir -p "$(dirname "$UP")"
cat > "$UP" <<'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Country;

class CountryUpdateProxy extends Controller
{
    public function __invoke(Request $request, Country $country)
    {
        $data = $request->validate([
            'name' => ['required','string','max:255'],
            'iso2' => ['nullable','string','size:2'],
        ]);
        if (isset($data['iso2'])) {
            $data['iso2'] = strtolower($data['iso2']);
        }
        $country->fill($data)->save();

        return redirect()
            ->route('countries.edit', $country)
            ->with('status', 'Country updated.');
    }
}
PHP

# 2) CountryMccController with duplicate-MCC friendly handling
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
        $mcc = $validated['mcc'];

        $log = session('log', []);

        $existing = DB::table('country_mccs')->where('mcc', $mcc)->first();
        if ($existing) {
            if ((int)$existing->country_id === (int)$country->id) {
                $log[] = ['level'=>'info', 'msg'=>"MCC $mcc already exists for {$country->name}."];
                return back()->with('log', $log);
            }
            $other = Country::find($existing->country_id);
            $otherName = $other ? $other->name : "country_id={$existing->country_id}";
            $log[] = ['level'=>'error', 'msg'=>"MCC $mcc is already assigned to {$otherName}. No changes made."];
            return back()->with('log', $log)->withInput();
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
        $log[] = $deleted
            ? ['level'=>'success','msg'=>"MCC $mcc removed from {$country->name}."]
            : ['level'=>'info','msg'=>"MCC $mcc not found for {$country->name} (nothing to remove)."];
        return back()->with('log', $log);
    }
}
PHP

# 3) Flash log Blade component
b "$FLASH"; mkdir -p "$(dirname "$FLASH")"
cat > "$FLASH" <<'BLADE'
@if (session('status'))
  <div class="mb-4 rounded border border-green-200 bg-green-50 p-3 text-green-800">
    {{ session('status') }}
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

@if (session('log'))
  <div class="mb-4 rounded border bg-gray-50 p-3">
    <div class="font-semibold text-gray-800">Log</div>
    <ul class="mt-2 space-y-1">
      @foreach (session('log') as $entry)
        @php $lvl = $entry['level'] ?? 'info'; @endphp
        <li class="@if($lvl==='error') text-red-700 @elseif($lvl==='success') text-green-700 @else text-gray-800 @endif">
          {{ $entry['msg'] ?? '' }}
        </li>
      @endforeach
    </ul>
  </div>
@endif
BLADE

# 4) Include log component on country edit page (simple insert after first <x-app-layout>)
b "$VC"
if ! grep -q "components/flash-log" "$VC"; then
  awk '
    {print}
    NR==1 && $0 ~ /<x-app-layout>/ {
      print "@include(\"components.flash-log\")"
    }
  ' "$VC" > "$VC.new" && mv "$VC.new" "$VC"
fi

# 5) Route swap: point PUT /countries/{country} to CountryUpdateProxy
b "$R"
perl -0777 -pe '
  s|Route::put\("/countries/\{country\}",\s*\[\s*\\\\App\\\\Http\\\\Controllers\\\\CountriesController::class,\s*["\']update["\']\s*\]\)->name\(["\']countries\.update["\']\);|Route::put("/countries/{country}", [\\App\\Http\\Controllers\\CountryUpdateProxy::class, "__invoke"])->name("countries.update");|g
' -i "$R"

# 6) Lint & warm
$DC exec -T app sh -lc '
  php -l app/Http/Controllers/CountryUpdateProxy.php
  php -l app/Http/Controllers/CountryMccController.php
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'
echo "==> Step4b_v2 complete."
