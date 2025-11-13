#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p resources/views/partials

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
if [ -f "$SID" ]; then
  cp -a "$SID" "$SID.bak.$(date +%F_%H-%M-%S)"
  php -r '
    $f="resources/views/partials/sidebar.blade.php";
    $s=file_get_contents($f);
    // remove any previous inline Countries/Networks blocks
    $s=preg_replace("#<a[^>]+route\\(\\'countries.index\\'\\)[\\s\\S]*?</a>\\s*#i","",$s);
    $s=preg_replace("#<a[^>]+route\\(\\'networks.index\\'\\)[\\s\\S]*?</a>\\s*#i","",$s);
    // insert include once, right before the first Settings link
    if (strpos($s,"partials.catalog_links")===false) {
      $s=preg_replace("#\\s*<a\\s+href=\\\"{{\\s*route\\(\\s*\\'settings\\.#","@include(\\'partials.catalog_links\\')\n\$0",$s,1);
      if ($s===null) { $s = \"@include('partials.catalog_links')\\n\".$s; }
    }
    file_put_contents($f,$s);
  '
else
  echo "Sidebar not found; add @include('partials.catalog_links') above Settings manually."
fi

echo "Sidebar updated."
