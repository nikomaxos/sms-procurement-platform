#!/usr/bin/env bash
set -Eeuo pipefail

CTR="app/Http/Controllers/NetworksController.php"
VIEW="resources/views/networks/index.blade.php"

echo "==> Patch controller (add mcc_mnc ILIKE + keep filters on pagination)"
mkdir -p tools

cat > tools/patch_net_ctrl_mccmnc.php <<'PHP'
<?php
$f = $argv[1] ?? 'app/Http/Controllers/NetworksController.php';
$s = file_get_contents($f);
if ($s === false) { fwrite(STDERR,"Missing $f\n"); exit(1); }

// 1) Inject mcc_mnc filter AFTER any existing 'mnc' filter.
//    Uses request() helper to avoid depending on param name ($r/$request).
if (stripos($s, "mcc_mnc") === false) {
  $pattern = "/(->when\\s*\\(\\s*[^\\)]*['\"]mnc['\"][^;]+;\\s*\\)\\s*)/is";
  $inject  = "$1\n        ->when(request()->filled('mcc_mnc'), function(\$q){ \$q->where('mcc_mnc','ilike','%'.request('mcc_mnc').'%'); })";
  $s2 = preg_replace($pattern, $inject, $s, 1);
  if ($s2 !== null) $s = $s2;
}

// 2) Ensure pagination appends query params so filters persist across pages.
if (!preg_match("/->paginate\\([^)]*\\)\\s*->appends\\(/", $s)) {
  $s = preg_replace("/->paginate\\(([^)]*)\\)\\s*;/", "->paginate($1)->appends(request()->all());", $s, 1);
}

file_put_contents($f, $s);
PHP

php tools/patch_net_ctrl_mccmnc.php "$CTR"

echo "==> Patch view (add MCC-MNC input to filter bar if missing)"
cat > tools/patch_net_view_mccmnc.php <<'PHP'
<?php
$f = $argv[1] ?? 'resources/views/networks/index.blade.php';
$s = file_get_contents($f);
if ($s === false) { fwrite(STDERR,"Missing $f\n"); exit(0); }

if (stripos($s, 'name="mcc_mnc"') === false) {
  // Try to insert right after the MNC input
  if (preg_match('/name="mnc"[^>]*>/', $s, $m, PREG_OFFSET_CAPTURE)) {
    $pos = $m[0][1] + strlen($m[0][0]);
    $ins = "\n        <input name=\"mcc_mnc\" value=\"{{ request('mcc_mnc') }}\" placeholder=\"MCC-MNC\" class=\"rounded border px-3 py-2\">";
    $s = substr($s,0,$pos).$ins.substr($s,$pos);
  } else {
    // Fallback: add inside the first GET <form>
    $s = preg_replace(
      '/(<form\\s+method="GET"[^>]*>)/i',
      "$1\n        <input name=\"mcc_mnc\" value=\"{{ request('mcc_mnc') }}\" placeholder=\"MCC-MNC\" class=\"rounded border px-3 py-2\">",
      $s, 1
    );
  }
  file_put_contents($f, $s);
}
PHP

php tools/patch_net_view_mccmnc.php "$VIEW"

echo "==> Clear caches (inside container)"
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan route:cache && php artisan view:cache'

echo "Done. Try: /networks?mcc_mnc=20207 (example)."
