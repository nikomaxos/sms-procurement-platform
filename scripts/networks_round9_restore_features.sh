#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> 0) Backups"
for f in \
  app/Models/NetworkMnc.php \
  app/Http/Controllers/CountriesController.php \
  resources/views/networks/index.blade.php \
  resources/views/networks/edit.blade.php
do
  [ -f "$f" ] && cp -a "$f" "$f.bak.$(date +%F_%H-%M-%S)" || true
done

echo "==> 1) Migration: add audit cols (created_by_user, updated_by_user) if missing"
mkdir -p database/migrations
MIG="database/migrations/2025_11_13_132900_add_audit_cols_to_network_mncs.php"
cat > "$MIG" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        if (Schema::hasTable('network_mncs')) {
            Schema::table('network_mncs', function (Blueprint $t) {
                if (!Schema::hasColumn('network_mncs','created_by_user')) {
                    $t->string('created_by_user', 100)->nullable()->after('mnc');
                }
                if (!Schema::hasColumn('network_mncs','updated_by_user')) {
                    $t->string('updated_by_user', 100)->nullable()->after('created_by_user');
                }
            });
            // safety: ensure mcc not null (fallback to empty string)
            DB::statement("update network_mncs set mcc = coalesce(mcc,'') where mcc is null");
        }
    }
    public function down(): void {
        if (Schema::hasTable('network_mncs')) {
            Schema::table('network_mncs', function (Blueprint $t) {
                if (Schema::hasColumn('network_mncs','updated_by_user')) $t->dropColumn('updated_by_user');
                if (Schema::hasColumn('network_mncs','created_by_user')) $t->dropColumn('created_by_user');
            });
        }
    }
};
PHP

echo "==> 2) Model: ensure NetworkMnc always computes mcc (fallback) + mcc_mnc"
mkdir -p app/Models
cat > app/Models/NetworkMnc.php <<'PHP'
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NetworkMnc extends Model {
    protected $fillable = [
        'network_id','mcc','mnc','mcc_mnc',
        'created_by_user','updated_by_user',
        'created_by_source','updated_by_source'
    ];

    protected static function booted() {
        static::saving(function ($m) {
            // Normalize
            $m->mcc = (string)($m->mcc ?? '');
            $m->mnc = (string)($m->mnc ?? '');
            // Fallback MCC if empty: network->mcc, else first existing MNC’s MCC, else first country MCC
            if ($m->mcc === '' && $m->network_id) {
                $net = $m->relationLoaded('network') ? $m->network : $m->network()->with(['mncs','country.mccs'])->first();
                $m->mcc = (string)($net->mcc
                    ?? optional($net->mncs->first())->mcc
                    ?? optional(optional($net->country)->mccs->first())->mcc
                    ?? '');
            }
            $m->mcc_mnc = (string)$m->mcc . (string)$m->mnc;
        });
    }

    public function network() { return $this->belongsTo(Network::class); }
}
PHP

echo "==> 3) CountriesController@edit: pass \$mccs to the view"
php -r '
$F="app/Http/Controllers/CountriesController.php";
if(!file_exists($F)){exit(0);}
$s=file_get_contents($F);
if(strpos($s,"function edit")!==false && strpos($s,"->with(\"mccs\"")===false){
  // inject $mccs = $country->mccs()->pluck("mcc")->all(); and attach to returned view
  $s=preg_replace(
    "/function\\s+edit\\s*\\(\\s*[^)]*\\)\\s*\\{/",
    "$0\n        \$mccs = \$country->mccs()->pluck(\"mcc\")->all();\n",
    $s,1
  );
  $s=preg_replace(
    "/return\\s+view\\(([^;]+)\\);/",
    "return view($1)->with(\"mccs\",\$mccs);",
    $s,1
  );
  file_put_contents($F,$s);
  echo "Patched $F\n";
} else { echo "No change $F\n"; }
'

echo "==> 4) Networks index: ensure Delete button column exists"
IDX="resources/views/networks/index.blade.php"
if [ -f "$IDX" ]; then
  # Header: add Actions if missing
  if ! grep -qi ">Actions<" "$IDX"; then
    sed -i '0,/<\/tr>/s//    <th class="px-3 py-2 text-left text-gray-600">Actions<\/th>\n  &/' "$IDX" || true
  fi
  # Body: try to detect @foreach ($networks as $n)
  if grep -q "@foreach (\\$networks as \\$" "$IDX"; then
    VAR="$(sed -n 's/.*@foreach (\$networks as \$/\1/p' "$IDX" | sed -n 's/).*//p' | head -n1)"
    [ -z "$VAR" ] && VAR="n"
    # Add an Actions td before </tr> of the row
    if ! grep -q "networks.destroy" "$IDX"; then
      awk -v v="$VAR" '
        BEGIN{add=1}
        {print}
        /<\/tr>/ && add==1 {
          print "      <td class=\"px-3 py-2 whitespace-nowrap\">";
          print "        <a href=\"{{ route('networks.edit', $"+v+") }}\" class=\"text-indigo-600 hover:underline mr-3\">Edit</a>";
          print "        <form action=\"{{ route('networks.destroy', $"+v+") }}\" method=\"POST\" class=\"inline\">";
          print "          @csrf @method('DELETE')";
          print "          <button type=\"submit\" onclick=\"return confirm('Delete this network?')\" class=\"text-red-600 hover:underline\">Delete</button>";
          print "        </form>";
          print "      </td>";
          add=0
        }' "$IDX" > "$IDX.tmp" && mv "$IDX.tmp" "$IDX"
    fi
  fi
fi

echo "==> 5) Networks edit: make primary MCC readonly (derived)"
EDIT="resources/views/networks/edit.blade.php"
if [ -f "$EDIT" ]; then
  # If there is an editable primary MCC input, make it readonly and set derived value
  if grep -q 'name="mcc"' "$EDIT"; then
    php -r '
      $f="resources/views/networks/edit.blade.php";
      $s=file_get_contents($f);
      $derived="{{ \$network->mcc ?? (\$network->mncs->first()->mcc ?? (optional(\$network->country->mccs->first())->mcc ?? \"\")) }}";
      $s=preg_replace(
        "/(<input[^>]*name=\\\"mcc\\\"[^>]*)(>)/i",
        "$1 value=\"".$derived."\" readonly class=\"w-full border rounded px-2 py-1 bg-gray-100\"$2",
        $s,1
      );
      file_put_contents($f,$s);
      echo "Patched $f\n";
    '
  fi
fi

echo "==> 6) Migrate + cache warmup"
$DC exec -T app sh -lc 'php artisan migrate --force'
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "==> Done."
