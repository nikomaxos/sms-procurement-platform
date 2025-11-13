#!/usr/bin/env bash
set -Eeuo pipefail

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

SID="resources/views/partials/sidebar.blade.php"
PART="resources/views/partials/catalog_links.blade.php"

# 1) Ensure the single partial we want to include (no icon text)
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

# 2) Dedupe & insert include via a tiny PHP script (avoids bash/regex quoting issues)
cp -a "$SID" "$SID.bak.$(date +%F_%H-%M-%S)"

php <<'PHP'
<?php
$f = 'resources/views/partials/sidebar.blade.php';
$s = file_get_contents($f);
if ($s === false) { fwrite(STDERR, "Cannot read $f\n"); exit(1); }

/* Remove any inline Countries/Networks anchors that were previously injected */
$s = preg_replace("#<a[^>]+route\\(\\s*['\\\"]countries\\.index['\\\"][^>]*>.*?</a>\\s*#si", "", $s);
$s = preg_replace("#<a[^>]+route\\(\\s*['\\\"]networks\\.index['\\\"][^>]*>.*?</a>\\s*#si", "", $s);

/* Remove any previous partial includes (old or new names) */
$s = preg_replace("/@include\\(\\s*['\\\"]partials\\.(catalog_links|countries_networks_links)['\\\"]\\s*\\)\\s*/i", "", $s);

/* Also strip any previous 'Catalogs' header blocks if they slipped in */
$s = preg_replace("#<div[^>]*>\\s*Catalogs\\s*</div>.*?(?=@include|<a|</aside>|$)#si", "", $s);

/* Build the single include we want */
$inc = "@include('partials.catalog_links')\n";

/* Insert it immediately before the first Settings link; fallback: prepend */
if (preg_match("/route\\(\\s*['\\\"]settings\\./i", $s, $m, PREG_OFFSET_CAPTURE)) {
    $pos = $m[0][1];
    $s = substr($s, 0, $pos) . $inc . substr($s, $pos);
} else {
    $s = $inc . $s;
}

file_put_contents($f, $s);
PHP

# 3) Warm caches inside the container so the sidebar re-renders cleanly
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "Sidebar deduped: exactly one Catalogs/Countries/Networks block remains above Settings."
