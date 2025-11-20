#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
say(){ printf "%b\n" "$*"; }

say "==> Step4: Audit & safety hardening"

############################################
# 0) Composer autoload sanity (fast)
############################################
php -v >/dev/null 2>&1 || { echo "PHP CLI not available"; exit 1; }

############################################
# 1) Migration: add audit cols to country_mccs (idempotent)
############################################
mkdir -p database/migrations
MIG_GLOB="database/migrations/*_add_audit_cols_to_country_mccs.php"
if ! ls $MIG_GLOB >/dev/null 2>&1; then
  ts_mig="$(date +%Y_%m_%d_%H%M%S)"
  cat > "database/migrations/${ts_mig}_add_audit_cols_to_country_mccs.php" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('country_mccs', function (Blueprint $table) {
            if (!Schema::hasColumn('country_mccs', 'marked_for_deletion')) {
                $table->boolean('marked_for_deletion')->default(false);
            }
            if (!Schema::hasColumn('country_mccs', 'created_by_user_id')) {
                $table->unsignedBigInteger('created_by_user_id')->nullable();
            }
            if (!Schema::hasColumn('country_mccs', 'updated_by_user_id')) {
                $table->unsignedBigInteger('updated_by_user_id')->nullable();
            }
            if (!Schema::hasColumn('country_mccs', 'created_by_source')) {
                $table->string('created_by_source', 64)->nullable();
            }
            if (!Schema::hasColumn('country_mccs', 'updated_by_source')) {
                $table->string('updated_by_source', 64)->nullable();
            }
        });
    }
    public function down(): void {
        Schema::table('country_mccs', function (Blueprint $table) {
            foreach (['marked_for_deletion','created_by_user_id','updated_by_user_id','created_by_source','updated_by_source'] as $col) {
                if (Schema::hasColumn('country_mccs', $col)) $table->dropColumn($col);
            }
        });
    }
};
PHP
  say "   created: migration for country_mccs audit cols"
else
  say "   migration for country_mccs audit cols already present"
fi

############################################
# 2) Model: NetworkMnc (provenance + helper)
############################################
mkdir -p app/Models
F_MOD=app/Models/NetworkMnc.php
b "$F_MOD"
cat > "$F_MOD" <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMnc extends Model
{
    protected $table = 'network_mncs';

    protected $fillable = [
        'network_id','mcc','mnc','mcc_mnc',
        'marked_for_deletion',
        'created_by_user_id','updated_by_user_id',
        'created_by_source','updated_by_source',
    ];

    protected $casts = [
        'marked_for_deletion' => 'bool',
    ];

    public function network(): BelongsTo
    {
        return $this->belongsTo(Network::class);
    }

    public function getMccMncFormattedAttribute(): string
    {
        $mcc = str_pad((string)$this->mcc, 3, '0', STR_PAD_LEFT);
        $mnc = str_pad((string)$this->mnc, 3, '0', STR_PAD_LEFT);
        return $mcc.$mnc;
    }
}
PHP
say "   wrote: app/Models/NetworkMnc.php"

############################################
# 3) Blade component for MNC chip w/ provenance tooltip
############################################
mkdir -p resources/views/components
F_CMP=resources/views/components/mnc-row.blade.php
b "$F_CMP"
cat > "$F_CMP" <<'BLADE'
@props(['mnc'])

@php
    $mcc = str_pad((string)($mnc->mcc ?? ''), 3, '0', STR_PAD_LEFT);
    $mncCode = str_pad((string)($mnc->mnc ?? ''), 3, '0', STR_PAD_LEFT);
    $src = $mnc->updated_by_source ?? $mnc->created_by_source ?? null;
    $title = "MCC {$mcc} / MNC {$mncCode}" . ($src ? " — source: {$src}" : "");
@endphp

<span
  class="inline-flex items-center gap-1 px-2 py-0.5 rounded border bg-white text-gray-700 text-xs"
  title="{{ $title }}"
>
  <span class="font-mono">{{ $mcc }}-{{ $mncCode }}</span>
  @if($src)
    <span class="opacity-60">({{ $src }})</span>
  @endif
</span>
BLADE
say "   wrote: resources/views/components/mnc-row.blade.php"

############################################
# 4) Importer service: provenance + safe upserts + zero-padding
############################################
mkdir -p app/Services
F_SVC=app/Services/CarrierImportService.php
b "$F_SVC"
cat > "$F_SVC" <<'PHP'
<?php
namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use App\Models\Country;
use App\Models\Network;

/**
 * Imports MCC/MNCs from remote JSON with local fallback and
 * writes provenance (created_by_source / updated_by_source).
 */
class CarrierImportService {

    /**
     * @return array{ok:bool,msg:string,createdCountries:int,createdNetworks:int,createdMncs:int}
     */
    public function import(string $source = 'itu', bool $fresh = false): array {
        $createdCountries = 0; $createdNetworks = 0; $createdMncs = 0;

        if ($fresh) {
            DB::table('network_mncs')->truncate();
            DB::table('country_mccs')->truncate();
        }

        // Determine provenance label
        $provenanceRemote = 'import:itu';
        $provenanceLocal  = 'import:local';

        // Data sources
        $urls = [
            // Canonical public table (schema: mcc, mnc, country, iso, brand/operator)
            'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
        ];

        // Try remote
        $rows = [];
        foreach ($urls as $url) {
            try {
                $res = Http::timeout(30)->get($url);
                if ($res->successful() && is_array($res->json())) {
                    $rows = array_merge($rows, $res->json());
                }
            } catch (\Throwable $e) {
                // ignore and try next
            }
        }

        $provenance = $rows ? $provenanceRemote : $provenanceLocal;

        // Fallback: local bundled JSON
        if (!$rows) {
            $path = base_path('resources/data/mcc-mnc-table.json');
            if (is_file($path)) {
                $data = json_decode((string)file_get_contents($path), true);
                if (is_array($data)) $rows = $data;
            }
        }

        if (!$rows) {
            return ['ok'=>false,'msg'=>'No data fetched from any source','createdCountries'=>0,'createdNetworks'=>0,'createdMncs'=>0];
        }

        // Dedupe within the batch to avoid redundant upserts
        $seenMccMnc = [];

        DB::transaction(function () use ($rows, &$createdCountries, &$createdNetworks, &$createdMncs, $provenance) {

            $hasLowerName = Schema::hasColumn('networks', 'lower_name');

            foreach ($rows as $r) {
                $mcc = trim((string)($r['mcc'] ?? $r['MCC'] ?? ''));
                $mnc = trim((string)($r['mnc'] ?? $r['MNC'] ?? ''));
                $cname = trim((string)($r['country'] ?? $r['country_name'] ?? $r['countryName'] ?? ''));
                $iso2  = strtolower(trim((string)($r['iso'] ?? $r['iso2'] ?? $r['country_code'] ?? '')));
                $netName = trim((string)($r['brand'] ?? $r['operator'] ?? $r['network'] ?? ''));

                if ($mcc === '' || $mnc === '' || $cname === '' || $netName === '') {
                    continue;
                }

                // Normalize & pad
                $mccPad = str_pad(preg_replace('/\D+/', '', $mcc), 3, '0', STR_PAD_LEFT);
                $mncPad = str_pad(preg_replace('/\D+/', '', $mnc), 3, '0', STR_PAD_LEFT);
                $mccMnc = $mccPad . $mncPad;

                // Country match → prefer ISO2 when available
                $country = null;
                if ($iso2 !== '') {
                    $country = Country::whereRaw('lower(iso2) = ?', [$iso2])->first();
                }
                if (!$country) {
                    $country = Country::whereRaw('lower(name) = ?', [mb_strtolower($cname)])->first();
                }
                if (!$country) {
                    $country = Country::create(['name' => $cname, 'iso2' => $iso2 ?: null]);
                    $createdCountries++;
                }

                // Network match by (country_id, lower(name))
                $lower = mb_strtolower($netName);
                $netQ = Network::where('country_id', $country->id)->whereRaw('lower(name) = ?', [$lower]);
                $network = $netQ->first();

                if (!$network) {
                    $attrs = ['country_id' => $country->id, 'name' => $netName];
                    if ($hasLowerName) $attrs['lower_name'] = $lower;
                    $network = Network::create($attrs);
                    $createdNetworks++;
                } else {
                    // Keep lower_name in sync if the column exists
                    if ($hasLowerName && $network->lower_name !== $lower) {
                        $network->lower_name = $lower;
                        $network->save();
                    }
                }

                // country_mccs upsert (unique per mcc)
                $existsCountryMcc = DB::table('country_mccs')->where('mcc', $mccPad)->exists();
                if ($existsCountryMcc) {
                    DB::table('country_mccs')
                      ->where('mcc', $mccPad)
                      ->update([
                          'country_id'        => $country->id,
                          'updated_by_source' => $provenance,
                          'updated_at'        => now(),
                      ]);
                } else {
                    DB::table('country_mccs')->insert([
                        'country_id'        => $country->id,
                        'mcc'               => $mccPad,
                        'created_by_source' => $provenance,
                        'updated_by_source' => $provenance,
                        'created_at'        => now(),
                        'updated_at'        => now(),
                    ]);
                }

                // network_mncs upsert (unique per (mcc,mnc))
                $key = $mccPad.'-'.$mncPad;
                if (isset($seenMccMnc[$key])) {
                    continue; // skip duplicates inside the same batch
                }
                $seenMccMnc[$key] = true;

                $existsMnc = DB::table('network_mncs')
                    ->where('mcc', $mccPad)->where('mnc', $mncPad)->exists();

                if ($existsMnc) {
                    DB::table('network_mncs')
                        ->where('mcc', $mccPad)
                        ->where('mnc', $mncPad)
                        ->update([
                            'network_id'        => $network->id,
                            'mcc_mnc'           => $mccMnc,
                            'updated_by_source' => $provenance,
                            'updated_at'        => now(),
                        ]);
                } else {
                    DB::table('network_mncs')->insert([
                        'network_id'        => $network->id,
                        'mcc'               => $mccPad,
                        'mnc'               => $mncPad,
                        'mcc_mnc'           => $mccMnc,
                        'created_by_source' => $provenance,
                        'updated_by_source' => $provenance,
                        'created_at'        => now(),
                        'updated_at'        => now(),
                    ]);
                    $createdMncs++;
                }
            }
        });

        return [
            'ok' => true,
            'msg' => 'Import completed',
            'createdCountries' => $createdCountries,
            'createdNetworks'  => $createdNetworks,
            'createdMncs'      => $createdMncs,
        ];
    }
}
PHP
say "   wrote: app/Services/CarrierImportService.php"

############################################
# 5) Optimize + migrate
############################################
php artisan optimize:clear
php artisan migrate --force
php artisan view:cache
php artisan route:cache

say "==> Step4 done. Now you can run: php artisan carriers:import --fresh"
