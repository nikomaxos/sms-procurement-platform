#!/usr/bin/env bash
set -Eeuo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

SID="resources/views/partials/sidebar.blade.php"
PART="resources/views/partials/catalog_links.blade.php"

# 1) Ensure the single partial that we want to include
mkdir -p "$(dirname "$PART")"
cat > "$PART" <<'BLADE'
<div class="mb-2">
  <div class="px-3 py-2 text-xs uppercase tracking-wide text-gray-500">Catalogs</div>
  <a href="{{ route('countries.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
    <span>Countries</span>
  </a>
  <a href="{{ route('networks.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
    <span>Networks</span>
  </a>
</div>
BLADE

# 2) Dedupe sidebar: remove any inline Countries/Networks blocks and old partial includes,
#    then insert a single include just before the first Settings link; fallback to prepend.
cp -a "$SID" "$SID.bak.$(date +%F_%H-%M-%S)"

php -r '
  $f = "'"$SID"'";
  $s = file_get_contents($f);
  if ($s === false) { fwrite(STDERR, "Cannot read $f\n"); exit(1); }

  // strip any inline anchors to countries/networks that were previously injected
  $s = preg_replace("#<a[^>]+route\\(\\s*[\\'\\\"]countries\\.index[\\'\\\"][^>]*>.*?</a>\\s*#si", "", $s);
  $s = preg_replace("#<a[^>]+route\\(\\s*[\\'\\\"]networks\\.index[\\'\\\"][^>]*>.*?</a>\\s*#si", "", $s);

  // strip any previous partial includes (both old and new names)
  $s = preg_replace("/@include\\(\\s*[\\'\\\"]partials\\.(catalog_links|countries_networks_links)[\\'\\\"]\\s*\\)\\s*/i", "", $s);

  // build the single include we want
  $inc = "@include(\'partials.catalog_links\')\n";

  // insert it immediately before the first Settings link if we can find one
  if (preg_match("/route\\(\\s*[\\'\\\"]settings\\./i", $s, $m, PREG_OFFSET_CAPTURE)) {
    $pos = $m[0][1];
    $s = substr($s, 0, $pos) . $inc . substr($s, $pos);
  } else {
    // fallback: prepend to the sidebar
    $s = $inc . $s;
  }

  file_put_contents($f, $s);
'

# 3) Warm caches inside container so the sidebar re-renders cleanly
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "Sidebar deduped: exactly one Catalogs/Countries/Networks block remains above Settings."
