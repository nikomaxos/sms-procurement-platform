# scripts/restore_sidebar_with_admin_items.sh
#!/usr/bin/env bash
set -Eeuo pipefail

SID="resources/views/partials/sidebar.blade.php"
mkdir -p "$(dirname "$SID")"

# Write a clean, minimal, valid sidebar (no Material Icons to avoid text leaking like "public")
cat > "$SID" <<'BLADE'
<div class="space-y-4">
  <!-- Dashboard -->
  <a href="{{ route('dashboard') }}" class="block px-3 py-2 rounded hover:bg-gray-100">Dashboard</a>

  <!-- Catalogs -->
  <div>
    <div class="px-3 py-2 text-xs uppercase tracking-wide text-gray-500">Catalogs</div>
    <a href="{{ route('countries.index') }}" class="block px-3 py-2 rounded hover:bg-gray-100">Countries</a>
    <a href="{{ route('networks.index') }}" class="block px-3 py-2 rounded hover:bg-gray-100">Networks</a>
  </div>

  <!-- Settings -->
  <div>
    <div class="px-3 py-2 text-xs uppercase tracking-wide text-gray-500">Settings</div>

    {{-- Drop Down Menus: visible to any authenticated user --}}
    <a href="{{ route('settings.dropdowns.index') }}" class="block px-3 py-2 rounded hover:bg-gray-100">Drop Down Menus</a>

    {{-- Admin-only links --}}
    @php $isAdmin = auth()->user() && (auth()->user()->is_admin ?? false); @endphp {{-- [Inference] uses is_admin boolean --}}
    @if($isAdmin)
      <a href="{{ route('settings.users.index') }}" class="block px-3 py-2 rounded hover:bg-gray-100">Users Management</a>
      <a href="{{ route('settings.imap.edit') }}" class="block px-3 py-2 rounded hover:bg-gray-100">IMAP Settings</a>
    @endif
  </div>
</div>
BLADE

# Warm caches in container
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "Sidebar restored and caches refreshed."
