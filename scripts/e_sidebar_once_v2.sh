#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p resources/views/partials

# Partial (once)
cat > resources/views/partials/catalog_links.blade.php <<'BLADE'
<div class="mb-2">
  <div class="px-3 py-2 text-xs uppercase tracking-wide text-gray-500">Catalogs</div>
  <a href="{{ route('countries.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
    <span class="material-icons text-sm">public</span><span>Countries</span>
  </a>
  <a href="{{ route('networks.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
    <span class="material-icons text-sm">cell_tower</span><span>Networks</span>
  </a>
</div>
BLADE

SID="resources/views/partials/sidebar.blade.php"
[ -f "$SID" ] || { echo "Sidebar not found: $SID"; exit 1; }
cp -a "$SID" "$SID.bak.$(date +%F_%H-%M-%S)"

# 1) Strip any existing inline Countries/Networks links (only the lines that contain the links)
tmp="$(mktemp)"; awk '
  !match($0, /route\(.?countries\.index/) && !match($0, /route\(.?networks\.index/)
' "$SID" > "$tmp" && mv "$tmp" "$SID"

# 2) Insert the include once, just before the first Settings link; if not found, prepend.
awk '
  BEGIN{ins=0}
  {
    if(ins==0 && $0 ~ /route\(.?settings\./){
      print "@include('\''partials.catalog_links'\'')"
      ins=1
    }
    print
  }
  END{
    if(ins==0){ print "@include('\''partials.catalog_links'\'')" }
  }
' "$SID" > "$SID.new" && mv "$SID.new" "$SID"

echo "Sidebar updated."
