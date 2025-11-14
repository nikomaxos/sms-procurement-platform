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
