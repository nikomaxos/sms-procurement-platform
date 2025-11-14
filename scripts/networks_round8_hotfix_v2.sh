#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

IMP="app/Console/Commands/ImportCarriers.php"
MODEL="app/Models/NetworkMnc.php"
COMP="resources/views/components/mnc-row.blade.php"
PATCH_DIR="tools/patches"
CTRL="app/Http/Controllers/NetworksController.php"

echo "==> Backups (if files exist)"
for f in "$IMP" "$MODEL" "$COMP" "$CTRL"; do
  [ -f "$f" ] && cp -a "$f" "$f.bak.$(date +%F_%H-%M-%S)" || true
done

echo "==> Ensure NetworkMnc model with auto mcc_mnc"
mkdir -p "$(dirname "$MODEL")"
cat > "$MODEL" <<'PHP'
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NetworkMnc extends Model {
    protected $fillable = [
        'network_id','mcc','mnc','mcc_mnc',
        'created_by_user','created_by_source','updated_by_user','updated_by_source'
    ];

    protected static function booted() {
        static::saving(function ($m) {
            $m->mcc = (string)($m->mcc ?? '');
            $m->mnc = (string)($m->mnc ?? '');
            $m->mcc_mnc = $m->mcc . $m->mnc;
        });
    }

    public function network() { return $this->belongsTo(Network::class); }
}
PHP

echo "==> Importer: switch to onomondo JSON + upsert under Networks/(country,lower(name))"
mkdir -p "$(dirname "$IMP")"
cat > "$IMP" <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use App\Models\Country;
use App\Models\CountryMcc;
use App\Models\Network;
use App\Models\NetworkMnc;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--source=itu} {--fresh : Clear MNC & MCC links before import}';
    protected $description = 'Import carriers from external sources (default: ITU JSON via onomondo repo)';

    public function handle() {
        $source = strtolower((string)($this->option('source') ?? 'itu'));

        if ($this->option('fresh')) {
            DB::statement('TRUNCATE network_mncs RESTART IDENTITY CASCADE');
            DB::statement('TRUNCATE country_mccs RESTART IDENTITY CASCADE');
            $this->info('Cleared network_mncs & country_mccs (networks kept).');
        }

        if ($source !== 'itu') {
            $this->error("Unknown source: {$source}");
            return self::FAILURE;
        }

        $url = 'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/data.json';
        try {
            $resp = Http::timeout(45)->withHeaders([
                'User-Agent' => 'sms-procurement-platform/1.0'
            ])->get($url);
        } catch (\Throwable $e) {
            $this->error('Cannot fetch ITU JSON: '.$e->getMessage());
            return self::FAILURE;
        }
        if (!$resp->ok()) {
            $this->error('Cannot fetch ITU JSON (HTTP '.$resp->status().')');
            return self::FAILURE;
        }

        $rows = $resp->json();
        if (!is_array($rows)) {
            $this->error('Unexpected JSON payload');
            return self::FAILURE;
        }

        $created = $updated = $linked = 0;

        foreach ($rows as $row) {
            $countryName = $row['country'] ?? $row['country_name'] ?? $row['Country'] ?? null;
            $iso2        = $row['alpha_2'] ?? $row['iso2'] ?? $row['ISO'] ?? 'n/a';
            $name        = $row['brand'] ?? $row['operator'] ?? $row['network'] ?? $row['Brand'] ?? null;
            $mcc         = (string)($row['mcc'] ?? $row['MCC'] ?? '');
            $mnc         = (string)($row['mnc'] ?? $row['MNC'] ?? '');

            if (!$countryName || !$name || $mcc === '' || $mnc === '') {
                continue;
            }

            $iso2 = strtolower(substr((string)$iso2, 0, 2) ?: 'n/a');

            $country = Country::firstOrCreate(
                ['name' => $countryName],
                ['iso2' => $iso2]
            );
            CountryMcc::firstOrCreate(['country_id' => $country->id, 'mcc' => $mcc]);

            $net = Network::where('country_id', $country->id)
                ->whereRaw('lower(name) = ?', [mb_strtolower($name, 'UTF-8')])
                ->first();

            if (!$net) {
                $net = new Network();
                $net->country_id = $country->id;
                $net->name = $name;
                if (array_key_exists('mcc', $net->getAttributes())) {
                    $net->mcc = $mcc;
                }
                $created++;
            } else {
                $updated++;
            }
            $net->updated_by_source = 'ITU import';
            $net->save();

            $nm = NetworkMnc::firstOrNew(['mcc' => $mcc, 'mnc' => $mnc]);
            $nm->network_id = $net->id;
            if (!$nm->exists) $nm->created_by_source = 'ITU import';
            $nm->updated_by_source = 'ITU import';
            $nm->save();
            $linked++;
        }

        $this->info("Import done. Networks: +$created created, ~$updated updated; MNC links: $linked");
        return self::SUCCESS;
    }
}
PHP

echo "==> Provide <x-mnc-row> to avoid missing component errors"
mkdir -p "$(dirname "$COMP")"
cat > "$COMP" <<'BLADE'
@props(['index'=>null,'m'=>null,'network'=>null])
@php
  $i = $index ?? ($loop->index ?? 0);
  $mnc = old("mncs.$i.mnc", $m->mnc ?? '');
  $mcc = $network->mcc ?? ($m->mcc ?? '');
  $mcc_mnc = ($mcc !== null && $mnc !== '') ? ($mcc.$mnc) : '';
@endphp
<div class="grid grid-cols-12 gap-2 items-center border-b py-2">
  <div class="col-span-3">
    <input name="mncs[{{ $i }}][mnc]" value="{{ $mnc }}" placeholder="MNC" class="w-full border rounded px-2 py-1">
  </div>
  <div class="col-span-3">
    <input value="{{ $mcc }}" class="w-full border rounded px-2 py-1 bg-gray-100" readonly>
  </div>
  <div class="col-span-4">
    <input value="{{ $mcc_mnc }}" class="w-full border rounded px-2 py-1 bg-gray-100" readonly>
  </div>
  <div class="col-span-2 text-right">
    <label class="inline-flex items-center gap-2">
      <input type="checkbox" name="mncs[{{ $i }}][remove]" value="1">
      <span>Remove</span>
    </label>
  </div>
</div>
BLADE

echo "==> Create controller patchers"
mkdir -p "$PATCH_DIR"

cat > "$PATCH_DIR/patch_networks_controller_v2.php" <<'PHP'
<?php
$ctrl = 'app/Http/Controllers/NetworksController.php';
if (!is_file($ctrl)) { fwrite(STDERR, "No NetworksController.php\n"); exit(0); }
$s = file_get_contents($ctrl);

// 1) Remove any previous bad coalesce/min subquery orderByRaw that lacks FROM
$s = preg_replace('/->orderByRaw\([^;]*coalesce[^;]*\);\s*/s', '', $s);

// 2) After orderBy("countries.name","asc") insert proper subquery ordering if not already present
$sub = "->orderByRaw(\"(select coalesce(min(nm.mcc::text || nm.mnc::text), '') from network_mncs nm where nm.network_id = networks.id) asc\")";
if (strpos($s, "network_mncs nm where nm.network_id = networks.id") === false) {
    $s = preg_replace(
        "/(->orderBy\(\s*'countries\.name'\s*,\s*'asc'\s*\)\s*)/i",
        "$1\n            $sub",
        $s,
        1
    );
}

// 3) Ensure edit() eager-loads mncs
if (preg_match('/function\s+edit\s*\(\s*[^)]*\)\s*\{/', $s, $m, PREG_OFFSET_CAPTURE)) {
    $pos = $m[0][1] + strlen($m[0][0]);
    if (strpos($s, "->load('mncs')") === false) {
        $s = substr($s,0,$pos) . "\n        \$network = \$network->load('mncs');\n" . substr($s,$pos);
    }
}

file_put_contents($ctrl, $s);
echo "Patched $ctrl\n";
PHP

echo "==> Apply controller patcher"
php "$PATCH_DIR/patch_networks_controller_v2.php"

echo "==> Clear & warm caches"
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "==> Done. Try an import:"
echo "    $DC exec -T app sh -lc '\''php artisan carriers:import --source=itu --fresh -v'\'''"
