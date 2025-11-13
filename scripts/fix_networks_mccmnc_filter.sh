#!/usr/bin/env bash
set -Eeuo pipefail
CTR="app/Http/Controllers/NetworksController.php"
VIEW="resources/views/networks/index.blade.php"

echo "==> Patch NetworksController@index to filter by mcc_mnc (ILIKE) and persist query on pagination"
php -r '
  $f=getenv("CTR") ?: "app/Http/Controllers/NetworksController.php";
  $s=file_get_contents($f);
  if($s===false){fwrite(STDERR,"Missing $f\n"); exit(1);}

  // Ensure we use Request class alias $r
  if(!preg_match("/function\\s+index\\s*\\(.*Request\\s+\\$r/",$s)){
    // Try to normalize signature to index(Request $r)
    $s=preg_replace(
      "/function\\s+index\\s*\\(([^)]*)\\)/",
      "function index(\\Illuminate\\Http\\Request \$r)",
      $s,1
    );
  }

  // Ensure mcc_mnc filter (ILIKE) exists; if not, inject next to mnc filter
  if(stripos($s,"mcc_mnc")===false){
    $s=preg_replace(
      "/(->when\\(\\s*\\$r->filled\\(\\s*[\\'\\\"]mnc[\\'\\\"]\\s*\\)\\s*,\\s*function\\s*\\(\\s*\\$q\\)\\s*use\\s*\\(\\s*\\$r\\s*\\)\\s*\\{\\s*\\$q->where\\(\\s*[\\'\\\"]mnc[\\'\\\"],?\\s*\\$r->mnc\\s*\\);\\s*\\}\\s*\\)\\s*)/is",
      "$1\n        ->when(\$r->filled('mcc_mnc'), function(\$q) use (\$r){ \$q->where('mcc_mnc','ilike','%'.\$r->mcc_mnc.'%'); })",
      $s,1
    );
  }

  // Ensure pagination appends query params
  if(!preg_match("/->paginate\\([^)]*\\)->appends\\(/",$s)){
    $s=preg_replace("/->paginate\\(([^)]*)\\)\\s*;/","->paginate($1)->appends(\$r->all());",$s,1);
  }

  file_put_contents($f,$s);
' CTR="$CTR"

echo "==> Ensure MCC-MNC input exists in networks index filter bar"
php -r '
  $f=getenv("VIEW") ?: "resources/views/networks/index.blade.php";
  $s=file_get_contents($f);
  if($s===false){fwrite(STDERR,"Missing $f\n"); exit(0);}

  if(stripos($s,"name=\"mcc_mnc\"")===false){
    // Insert an input next to existing mcc/mnc inputs (after mnc if found)
    if(preg_match("/name=\\\"mnc\\\"[^>]*>/i",$s,$m,PREG_OFFSET_CAPTURE)){
      $pos=$m[0][1]+strlen($m[0][0]);
      $ins="\n        <input name=\"mcc_mnc\" value=\"{{ request('mcc_mnc') }}\" placeholder=\"MCC-MNC\" class=\"rounded border px-3 py-2\">";
      $s=substr($s,0,$pos).$ins.substr($s,$pos);
    } else {
      // Otherwise append to the first filter <form>
      $s=preg_replace(
        "/(<form\\s+method=\\\"GET\\\"[^>]*>)/i",
        "$1\n        <input name=\"mcc_mnc\" value=\"{{ request('mcc_mnc') }}\" placeholder=\"MCC-MNC\" class=\"rounded border px-3 py-2\">",
        $s,1
      );
    }
    file_put_contents($f,$s);
  }
'

echo "==> Clear caches"
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan route:cache && php artisan view:cache'
echo "Done. Try filtering with ?mcc_mnc=20207 (example)."
