#!/usr/bin/env bash
set -Eeuo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
F="resources/views/networks/index.blade.php"
[ -f "$F" ] || { echo "Missing $F"; exit 1; }
cp -a "$F" "$F.bak.$(date +%F_%H-%M-%S)"

# 1) Add header "Actions" (if not present)
if ! grep -qi '>Actions<' "$F"; then
  php -r '
    $f="resources/views/networks/index.blade.php";
    $s=file_get_contents($f);
    $s=preg_replace("/(<thead>.*?<tr[^>]*>.*?)(<\/tr>)/si",
      "$1\n    <th class=\"px-3 py-2 text-left text-gray-600\">Actions</th>\n  $2", $s, 1);
    file_put_contents($f,$s);
  '
fi

# 2) Add body cell with Edit/Delete (coalesce row var: $n ?? $network)
if ! grep -q "networks.destroy" "$F"; then
  php -r '
    $f="resources/views/networks/index.blade.php";
    $s=file_get_contents($f);
    // Insert before the first closing </tr> inside tbody row
    $cell = "\n      <td class=\"px-3 py-2 whitespace-nowrap\">".
            "\n        <a href=\"{{ route(\'networks.edit\', (\$n ?? \$network)) }}\" class=\"text-indigo-600 hover:underline mr-3\">Edit</a>".
            "\n        <form action=\"{{ route(\'networks.destroy\', (\$n ?? \$network)) }}\" method=\"POST\" class=\"inline\">".
            "\n          @csrf @method(\'DELETE\')".
            "\n          <button type=\"submit\" onclick=\"return confirm(\'Delete this network?\')\" class=\"text-red-600 hover:underline\">Delete</button>".
            "\n        </form>\n      </td>";
    // try to inject after the last </td> in the first data row
    $s=preg_replace("/(\\n\\s*<\\/tr>)/", $cell."$1", $s, 1);
    file_put_contents($f,$s);
  '
fi

$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "OK: Actions column restored."
