#!/usr/bin/env bash

echo "==> offers_add_actions_and_mass_row_v1: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || { echo "!! Could not cd to project root"; exit 1; }

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/offers_add_actions_and_mass_row_v1_${STAMP}"
mkdir -p "$BACKUP_DIR"

INDEX="resources/views/offers/index.blade.php"

if [[ ! -f "$INDEX" ]]; then
  echo "!! $INDEX not found, aborting"
  exit 1
fi

echo "   - Backing up $INDEX to $BACKUP_DIR/$INDEX"
mkdir -p "$BACKUP_DIR/$(dirname "$INDEX")"
cp "$INDEX" "$BACKUP_DIR/$INDEX"

# ------------------------------------------------------------
# 1) Add "Actions" column to the table header
# ------------------------------------------------------------
echo "==> Adding Actions column header (if not already present)"
perl -0pi -e '
    unless (/Actions<\/th>/) {
        s#(<thead>\s*<tr[^>]*>)(.*?)(</tr>)#$1$2\n                        <th class="px-3 py-2 text-right">Actions</th>\n                    $3#s;
    }
' "$INDEX"

# ------------------------------------------------------------
# 2) Add Edit/Delete cells to the offer row template
# ------------------------------------------------------------
echo "==> Adding Actions cells (Edit/Delete) to the offers row template"
perl -0pi -e '
    my $pattern = qr/@forelse\s*\(\s*\$offers\s+as\s+\$offer\s*\)\s*<tr[^>]*>(.*?)<\/tr>/s;
    if ($_ !~ /route\(\'offers\.edit\'/) {
        s#$pattern#@forelse (\$offers as \$offer)\n                    <tr>\n$1\n                        <td class="px-3 py-2 text-right whitespace-nowrap">\n                            <a href="{{ route(\'offers.edit\', \$offer) }}" class="inline-flex items-center px-2 py-1 border border-gray-300 rounded text-xs text-gray-700 hover:bg-gray-50">Edit</a>\n                            <form action="{{ route(\'offers.destroy\', \$offer) }}" method="POST" class="inline-block" onsubmit="return confirm(\'Delete this offer?\');">\n                                @csrf\n                                @method(\'DELETE\')\n                                <button type="submit" class="inline-flex items-center px-2 py-1 border border-red-300 rounded text-xs text-red-700 hover:bg-red-50">Delete</button>\n                            </form>\n                        </td>\n                    </tr>#s;
    }
' "$INDEX"

# ------------------------------------------------------------
# 3) Try to force Mass Update controls into one row on desktop
# ------------------------------------------------------------
echo "==> Tweaking Mass update section layout (single row on desktop where possible)"
perl -0pi -e '
    s#(<h3 class="text-sm font-semibold text-gray-800 mb-3">\s*Mass update selected offers\s*</h3>\s*)<div class="[^"]*">#$1<div class="flex flex-wrap md:flex-nowrap items-end gap-4">#s;
' "$INDEX"

echo "==> Done. If something looks wrong, restore from:"
echo "   $BACKUP_DIR/$INDEX"
