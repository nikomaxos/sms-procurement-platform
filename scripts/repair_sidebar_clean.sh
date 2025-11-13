#!/usr/bin/env bash
set -Eeuo pipefail

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

SID="resources/views/partials/sidebar.blade.php"
PART="resources/views/partials/catalog_links.blade.php"

echo "==> Backup current sidebar"
mkdir -p resources/views/partials
cp -a "$SID" "$SID.bak.$(date +%F_%H-%M-%S)" 2>/dev/null || true

echo "==> Write clean Catalogs partial (no icon glyphs)"
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

echo "==> Write known-good sidebar (single Catalogs block above Settings)"
cat > "$SID" <<'BLADE'
{{-- Clean sidebar rebuilt on demand --}}
<aside class="w-64 shrink-0">
  <nav class="py-4 text-sm">
    <a href="{{ route('dashboard') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
      <span>Dashboard</span>
    </a>

    @include('partials.catalog_links')

    <div class="px-3 py-2 text-xs uppercase tracking-wide text-gray-500">Settings</div>
    <a href="{{ route('settings.imap.edit') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
      <span>IMAP Settings</span>
    </a>
    <a href="{{ route('settings.dropdowns.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
      <span>Drop Downs</span>
    </a>
  </nav>
</aside>
BLADE

echo "==> Clear & warm caches inside container"
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "Done. Sidebar rebuilt and caches warmed."
