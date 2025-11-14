#!/usr/bin/env bash
set -Eeuo pipefail
F="resources/views/networks/index.blade.php"
[ -f "$F" ] || { echo "Missing $F"; exit 1; }
cp -a "$F" "$F.bak.$(date +%F_%H-%M-%S)"

php -r <<'PHP'
$f = "resources/views/networks/index.blade.php";
$s = file_get_contents($f);

// 1) Fix header
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
$s = preg_replace('/<thead class="bg-gray-50">.*?<\/thead>/si', $hdr, $s, 1);

// 2) Replace the current right-aligned Edit-only TD with Edit+Delete
$actions = <<<'ACT'
<td class="px-4 py-2 text-right">
  <a href="{{ route('networks.edit', $n) }}" class="text-indigo-600 hover:underline mr-3">Edit</a>
  <form action="{{ route('networks.destroy', $n) }}" method="POST" class="inline">
    @csrf @method('DELETE')
    <button type="submit" onclick="return confirm('Delete this network?')" class="text-red-600 hover:underline">Delete</button>
  </form>
</td>
ACT;
$s = preg_replace('/<td class="px-4 py-2 text-right">.*?<\/td>/si', $actions, $s, 1);

file_put_contents($f, $s);
PHP

# warm caches
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "OK: Networks header + Actions column fixed."
