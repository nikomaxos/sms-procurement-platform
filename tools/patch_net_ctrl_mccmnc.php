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
