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
