#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Step4c: duplicate-MCC guard + flash log panel on country edit"

# 1) Write a robust CountryMccController (store + destroy with log panel support)
F=app/Http/Controllers/CountryMccController.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\Country;

class CountryMccController extends Controller
{
    public function store(Request $request, Country $country)
    {
        $mcc = trim((string)$request->input('mcc',''));
        $log = [];

        // Validate format: exactly 3 digits
        if (!preg_match('/^\d{3}$/', $mcc)) {
            $log[] = "Invalid MCC format: $mcc (must be exactly 3 digits)";
            return back()->with('error','MCC must be exactly 3 digits.')->with('log',$log);
        }

        // Global uniqueness check (country_mccs.mcc is unique)
        $existing = DB::table('country_mccs')->where('mcc', $mcc)->first();

        if ($existing) {
            if ((int)$existing->country_id === (int)$country->id) {
                $log[] = "MCC $mcc already exists for {$country->name}.";
                return back()->with('status','Nothing to change.')->with('log',$log);
            } else {
                $ownerName = optional(Country::find($existing->country_id))->name ?? ("ID {$existing->country_id}");
                $log[] = "MCC $mcc is owned by $ownerName.";
                return back()->with('error',"MCC $mcc already assigned to $ownerName.")->with('log',$log);
            }
        }

        DB::table('country_mccs')->insert([
            'country_id' => $country->id,
            'mcc'        => $mcc,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $log[] = "Added MCC $mcc to {$country->name}.";
        return back()->with('status','MCC added.')->with('log',$log);
    }

    public function destroy(Country $country, string $mcc)
    {
        $log = [];
        $row = DB::table('country_mccs')
            ->where('country_id', $country->id)
            ->where('mcc', $mcc)
            ->first();

        if (!$row) {
            $log[] = "MCC $mcc not found for {$country->name}.";
            return back()->with('error',"MCC $mcc not found for this country.")->with('log',$log);
        }

        DB::table('country_mccs')->where('id', $row->id)->delete();

        $log[] = "Removed MCC $mcc from {$country->name}.";
        return back()->with('status','MCC removed.')->with('log',$log);
    }
}
PHP

# 2) Add a reusable flash/log panel partial
P=resources/views/partials/flash_log.blade.php
b "$P"; mkdir -p "$(dirname "$P")"
cat > "$P" <<'BLADE'
@if (session('status'))
  <div class="mb-3 rounded border border-green-300 bg-green-50 p-3 text-green-800">
    {{ session('status') }}
  </div>
@endif
@if (session('error'))
  <div class="mb-3 rounded border border-red-300 bg-red-50 p-3 text-red-800">
    {{ session('error') }}
  </div>
@endif
@if (session('log'))
  <div class="mb-4 rounded border border-gray-300 bg-gray-50 p-3 text-gray-800">
    <div class="font-semibold mb-1">Log</div>
    <ul class="list-disc ml-5 text-sm">
      @foreach (session('log') as $line)
        <li>{{ $line }}</li>
      @endforeach
    </ul>
  </div>
@endif
BLADE

# 3) Include the panel in countries/edit view (after <x-app-layout>)
E=resources/views/countries/edit.blade.php
b "$E"
if ! grep -Fq "@include('partials.flash_log')" "$E"; then
  awk '{
    print;
    if (!inserted && $0 ~ /<x-app-layout>/) { print "    @include('\''partials.flash_log'\'')"; inserted=1 }
  }' "$E" > "$E.tmp" && mv "$E.tmp" "$E"
fi

# 4) Lint & rebuild caches
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l app/Http/Controllers/CountryMccController.php
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'
echo "==> Step4c complete."
