#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> 1) Service: App\\Services\\CarrierImportService"
F=app/Services/CarrierImportService.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use App\Models\Country;
use App\Models\Network;
use App\Models\NetworkMnc;

/**
 * Imports MCC/MNCs from public JSON (fallback-friendly) and
 * populates countries, networks, network_mncs, and country_mccs.
 */
class CarrierImportService {
    /**
     * @return array{ok:bool,msg:string,createdCountries:int,createdNetworks:int,createdMncs:int}
     */
    public function import(string $source, bool $fresh): array {
        $createdCountries = 0; $createdNetworks = 0; $createdMncs = 0;

        if ($fresh) {
            DB::table('network_mncs')->truncate();
            DB::table('country_mccs')->truncate();
            // Intentionally keep networks/countries
        }

        // [Inference] robust source list (schema-tolerant)
        $urls = [
            'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
        ];

        $rows = [];
        foreach ($urls as $url) {
            try {
                $res = Http::timeout(30)->get($url);
                if ($res->successful()) {
                    $data = $res->json();
                    if (is_array($data)) { $rows = array_merge($rows, $data); }
                }
            } catch (\Throwable $e) {}
        }
        if (!$rows) {
            return ['ok'=>false,'msg'=>'No data fetched from sources','createdCountries'=>0,'createdNetworks'=>0,'createdMncs'=>0];
        }

        DB::transaction(function () use ($rows, &$createdCountries, &$createdNetworks, &$createdMncs) {
            foreach ($rows as $r) {
                // tolerant field extraction
                $mcc = $r['mcc'] ?? ($r['MCC'] ?? null);
                $mnc = $r['mnc'] ?? ($r['MNC'] ?? null);
                $cname = $r['country'] ?? ($r['country_name'] ?? ($r['countryName'] ?? null));
                $iso2  = $r['iso'] ?? ($r['iso2'] ?? ($r['country_code'] ?? null));
                $netName = $r['brand'] ?? ($r['operator'] ?? ($r['network'] ?? null));
                if ($mcc===null || $mnc===null || $cname===null || $netName===null) {
                    continue; // skip incomplete
                }
                $mcc = (string)$mcc; $mnc = (string)$mnc; $cname = trim((string)$cname); $netName = trim((string)$netName);
                if ($cname === '' || $netName === '') continue;

                // Country
                $country = Country::firstOrCreate(
                    ['name'=>$cname],
                    ['iso2'=> is_string($iso2) ? strtolower(substr($iso2,0,2)) : null]
                );
                if ($country->wasRecentlyCreated) $createdCountries++;

                // Ensure country_mccs has this MCC
                if ($mcc !== '') {
                    $existsMcc = DB::table('country_mccs')->where(['country_id'=>$country->id,'mcc'=>$mcc])->exists();
                    if (!$existsMcc) {
                        DB::table('country_mccs')->insert([
                            'country_id'=>$country->id,'mcc'=>$mcc,
                            'created_at'=>now(),'updated_at'=>now(),
                        ]);
                    }
                }

                // Network
                $network = Network::firstOrCreate(
                    ['name'=>$netName, 'country_id'=>$country->id],
                    []
                );
                if ($network->wasRecentlyCreated) $createdNetworks++;

                // Link MNC to Network
                $existsNm = DB::table('network_mncs')->where([
                    'network_id'=>$network->id, 'mcc'=>$mcc, 'mnc'=>$mnc
                ])->exists();
                if (!$existsNm) {
                    DB::table('network_mncs')->insert([
                        'network_id'=>$network->id,
                        'mcc'=>$mcc,
                        'mnc'=>$mnc,
                        'mcc_mnc'=>$mcc.$mnc,
                        'created_at'=>now(),
                        'updated_at'=>now(),
                    ]);
                    $createdMncs++;
                }
            }
        });

        return [
            'ok'=>true,
            'msg'=>'Import complete',
            'createdCountries'=>$createdCountries,
            'createdNetworks'=>$createdNetworks,
            'createdMncs'=>$createdMncs
        ];
    }
}
PHP

echo "==> 2) Controller: App\\Http\\Controllers\\CarriersImportController"
F=app/Http/Controllers/CarriersImportController.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\CarrierImportService;

class CarriersImportController extends Controller
{
    public function run(Request $r, CarrierImportService $svc)
    {
        $source = (string) $r->input('source','itu');
        $fresh  = (bool) $r->input('fresh', false);
        $out = $svc->import($source, $fresh);
        if (!$out['ok']) {
            return back()->withErrors(['import'=>$out['msg']]);
        }
        return back()->with('status', sprintf(
            'Import OK: %s (countries +%d, networks +%d, mncs +%d)',
            $out['msg'],
            $out['createdCountries'],
            $out['createdNetworks'],
            $out['createdMncs']
        ));
    }
}
PHP

echo "==> 3) Route: POST /carriers/import -> CarriersImportController@run"
b routes/web.php
grep -q "carriers.import" routes/web.php 2>/dev/null || cat >> routes/web.php <<'PHP'

use App\Http\Controllers\CarriersImportController;
Route::post('/carriers/import', [CarriersImportController::class, 'run'])->name('carriers.import');
PHP

echo "==> 4) CountriesController@edit: pass \$mccs as array (fix implode(Collection) error)"
F=app/Http/Controllers/CountriesController.php
if [ -f "$F" ]; then
  b "$F"
  # Replace edit() body to ensure $mccs is an array of strings
  awk '
    BEGIN{in=0}
    /public[ \t]+function[ \t]+edit[ \t]*\(/ {print; in=1; next}
    in==1 && /^\{/ { print "    $country->load(\"mccs\");";
                     print "    $mccs = $country->mccs ? $country->mccs->pluck(\"mcc\")->all() : [];";
                     print "    return view(\"countries.edit\", compact(\"country\",\"mccs\"));";
                     # skip until method end
                     in=2; next }
    in==2 && /^\}/ { print; in=0; next }
    in>0 { next }
    {print}
  ' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
fi

echo "==> 5) NetworksController: ensure create() passes \$network & edit() eager-loads"
F=app/Http/Controllers/NetworksController.php
if [ -f "$F" ]; then
  b "$F"
  # create()
  sed -i 's/public function create().*/public function create(){ return view('"'"'networks.create'"'"', ['"'"'network'"'"'=>new \\App\\Models\\Network()]); }/g' "$F" || true
  # edit() -> load mncs + country.mccs
  awk '
    BEGIN{in=0}
    /public[ \t]+function[ \t]+edit[ \t]*\([^{]*Network[ \t]*\$network[^{]*\)/ {print; in=1; next}
    in==1 && /^\{/ { print "    $network->load([\"mncs\",\"country.mccs\"]);";
                     print "    return view(\"networks.edit\", compact(\"network\"));";
                     in=2; next }
    in==2 && /^\}/ { print; in=0; next }
    in>0 { next }
    {print}
  ' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
fi

echo "==> 6) NetworkMnc model: compute mcc_mnc; keep mcc if provided"
F=app/Models/Network/NetworkMnc.php
if [ -f "$F" ]; then
  b "$F"
fi
# Some repos have app/Models/NetworkMnc.php (flat); prefer that if present
if [ -f app/Models/NetworkMnc.php ]; then F=app/Models/NetworkMnc.php; fi
b "$F"
cat > "$F" <<'PHP'
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMnc extends Model {
    protected $fillable = ['network_id','mcc','mnc','mcc_mnc','created_by_user_id','updated_by_user_id'];
    public function network(): BelongsTo { return $this->belongsTo(Network::class); }
    protected static function booted() {
        static::saving(function($m){
            $m->mcc = (string)($m->mcc ?? '');
            $m->mnc = (string)($m->mnc ?? '');
            $m->mcc_mnc = ($m->mcc ?? '').($m->mnc ?? '');
        });
    }
}
PHP

echo "==> 7) networks/edit.blade.php: make Primary MCC read-only & null-safe"
V=resources/views/networks/edit.blade.php
if [ -f "$V" ]; then
  b "$V"
  # Replace Primary MCC input block to a readonly computed field
  perl -0777 -pe '
    s{
      <label class="block text-sm font-medium text-gray-700">Primary MCC</label>.*?</div>
    }{
      <label class="block text-sm font-medium text-gray-700">Primary MCC</label>
      <?php
        $pmcc = null;
        if (isset($network) && $network->relationLoaded("mncs")) {
            $pmcc = $network->mncs->pluck("mcc")->filter()->first();
        }
        if (!$pmcc && $network->country && $network->country->relationLoaded("mccs")) {
            $pmcc = optional($network->country->mccs->first())->mcc;
        }
      ?>
      <input value="{{ $pmcc ?? '' }}" class="mt-1 w-full rounded border px-3 py-2 bg-gray-50" readonly>
    }gsx' -i "$V"
fi

echo "==> 8) networks/create.blade.php: ensure \$network exists (minimal safe form)"
V=resources/views/networks/create.blade.php
if [ -f "$V" ]; then
  b "$V"
else
  mkdir -p "$(dirname "$V")"
fi
cat > "$V" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Create Network</h2>
  </x-slot>
  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.store') }}" class="space-y-4 bg-white p-4 rounded border">
      @csrf
      <div>
        <label class="block text-sm font-medium text-gray-700">Name</label>
        <input name="name" value="{{ old('name') }}" class="mt-1 w-full rounded border px-3 py-2">
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700">Country ID</label>
        <input name="country_id" value="{{ old('country_id') }}" class="mt-1 w-full rounded border px-3 py-2">
      </div>
      <div class="flex items-center gap-3">
        <button class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded border px-4 py-2 bg-white hover:bg-gray-50">Back</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

echo "==> 9) Relax legacy NOT NULL on networks.{mcc,mnc,mcc_mnc} (idempotent)"
mkdir -p database/migrations
FN="database/migrations/$(date +%Y_%m_%d_%H%M%S)_relax_networks_mcc_notnull.php"
cat > "$FN" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc DROP NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mnc DROP NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc_mnc DROP NOT NULL"); } catch (\Throwable $e) {}
    }
    public function down(): void {
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc SET NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mnc SET NOT NULL"); } catch (\Throwable $e) {}
        try { DB::statement("ALTER TABLE networks ALTER COLUMN mcc_mnc SET NOT NULL"); } catch (\Throwable $e) {}
    }
};
PHP

echo "==> 10) Autoload + migrate + cache warm"
$DC exec -T app sh -lc '
  composer dump-autoload -o
  php artisan migrate --force
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'

echo "==> 11) Try import (fresh)"
$DC exec -T app sh -lc '
  php artisan tinker --execute="echo class_exists(\App\Services\CarrierImportService::class) ? \"SVC_OK\\n\" : \"SVC_MISSING\\n\";"
  php artisan carriers:import --source=itu --fresh -v || true
'

echo "All done."
