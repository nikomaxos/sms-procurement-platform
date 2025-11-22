#!/usr/bin/env bash
set -euo pipefail

##
# add_suppliers_nav_link_v1.sh
#
# Injects a "Suppliers" menu item next to "Networks" in the main navigation
# (both desktop and responsive). Safe to run multiple times.
##

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
  pwd
)"

cd "$ROOT_DIR"

NAV="resources/views/layouts/navigation.blade.php"

if [[ ! -f "$NAV" ]]; then
  echo "ERROR: ${NAV} not found. Are you in the project root?" >&2
  exit 1
fi

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/add_suppliers_nav_${STAMP}"

echo "==> Backing up navigation.blade.php to ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"
cp "${NAV}" "${BACKUP_DIR}/navigation.blade.php"

# If Suppliers link already exists, do nothing
if grep -q "suppliers.index" "$NAV"; then
  echo "==> Suppliers nav entry already present; nothing to do."
  exit 0
fi

echo "==> Patching desktop navigation to add Suppliers after Networks"

# Desktop nav (Breeze-style :href="route('networks.index')")
perl -0pi -e '
  s#(
        <x-nav-link\s+[^>]*:href="route\('\''networks.index'\''\)"[^>]*>
        .*?
        </x-nav-link>
    )#$1\n            <x-nav-link :href="route('\''suppliers.index'\'')" :active="request()->routeIs('\''suppliers.*'\'')">\n                {{ __( '\''Suppliers'\'' ) }}\n            </x-nav-link>#gsx
' "$NAV"

# Fallback desktop nav (non-colon href="{{ route('networks.index') }}")
perl -0pi -e '
  s#(
        <x-nav-link\s+[^>]*href="{{\s*route\('\''networks.index'\''\)\s*}}"[^>]*>
        .*?
        </x-nav-link>
    )#$1\n            <x-nav-link href="{{ route('\''suppliers.index'\'') }}" :active="request()->routeIs('\''suppliers.*'\'')">\n                {{ __( '\''Suppliers'\'' ) }}\n            </x-nav-link>#gsx
' "$NAV"

echo "==> Patching responsive (mobile) navigation to add Suppliers after Networks"

# Mobile nav (Breeze-style)
perl -0pi -e '
  s#(
        <x-responsive-nav-link\s+[^>]*:href="route\('\''networks.index'\''\)"[^>]*>
        .*?
        </x-responsive-nav-link>
    )#$1\n            <x-responsive-nav-link :href="route('\''suppliers.index'\'')" :active="request()->routeIs('\''suppliers.*'\'')">\n                {{ __( '\''Suppliers'\'' ) }}\n            </x-responsive-nav-link>#gsx
' "$NAV"

# Fallback mobile nav (non-colon style)
perl -0pi -e '
  s#(
        <x-responsive-nav-link\s+[^>]*href="{{\s*route\('\''networks.index'\''\)\s*}}"[^>]*>
        .*?
        </x-responsive-nav-link>
    )#$1\n            <x-responsive-nav-link href="{{ route('\''suppliers.index'\'') }}" :active="request()->routeIs('\''suppliers.*'\'')">\n                {{ __( '\''Suppliers'\'' ) }}\n            </x-responsive-nav-link>#gsx
' "$NAV"

echo "==> Done. navigation.blade.php patched."
echo "    Backup stored at: ${BACKUP_DIR}/navigation.blade.php"
