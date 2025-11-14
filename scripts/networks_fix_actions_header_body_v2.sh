#!/usr/bin/env bash
set -Eeuo pipefail

F="resources/views/networks/index.blade.php"
[ -f "$F" ] || { echo "Missing $F"; exit 1; }
cp -a "$F" "$F.bak.$(date +%F_%H-%M-%S)"

php <<'PHP'
<?php
$f = "resources/views/networks/index.blade.php";
$s = file_get_contents($f);
if ($s === false) { fwrite(STDERR, "Cannot read $f\n"); exit(1); }

/* 1) Replace the THEAD with a correct 4-col header */
$hdr = <<<'HDR'
<thead class="bg-gray-50">
  <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
    <th class="px-4 py-3">Country</th>
    <th class="px-4 py-3">Network</th>
    <th class="px-4 py-3">MNCs</th>
    <th class="px-4 py-3">Actions</th>
  </tr>
</thead>
HDR;
$s2 = preg_replace('/<thead class="bg-gray-50">.*?<\/thead>/s', $hdr, $s, 1);
if ($s2 === null) { fwrite(STDERR, "Regex error on THEAD replace\n"); exit(1); }
$s = $s2;

/* 2) Replace the first right-aligned Actions TD with Edit + Delete */
$actions = <<<'ACT'
<td class="px-4 py-2 text-right">
  <a href="{{ route('networks.edit', $n) }}" class="text-indigo-600 hover:underline mr-3">Edit</a>
  <form action="{{ route('networks.destroy', $n) }}" method="POST" class="inline">
    @csrf @method('DELETE')
    <button type="submit" onclick="return confirm('Delete this network?')" class="text-red-600 hover:underline">Delete</button>
  </form>
</td>
ACT;
$s2 = preg_replace('/<td class="px-4 py-2 text-right">.*?<\/td>/s', $actions, $s, 1);
if ($s2 === null) { fwrite(STDERR, "Regex error on TD replace\n"); exit(1); }
$s = $s2;

if (file_put_contents($f, $s) === false) { fwrite(STDERR, "Cannot write $f\n"); exit(1); }
echo "Patched $f\n";
PHP

# Warm caches inside the PHP container
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "OK: Networks header + Actions column fixed and caches warmed."
