# scripts/restore_admin_sidebar_v3.sh
#!/usr/bin/env bash
set -Eeuo pipefail

SID="resources/views/partials/sidebar.blade.php"
mkdir -p "$(dirname "$SID")"

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

    @if (\Illuminate\Support\Facades\Route::has('settings.dropdowns.index'))
      <a href="{{ route('settings.dropdowns.index') }}" class="block px-3 py-2 rounded hover:bg-gray-100">Drop Down Menus</a>
    @endif

    @php
      $u = auth()->user();
      $isAdmin = $u && (
        (($u->is_admin ?? false) === true) ||
        (($u->admin ?? false) === true) ||
        (isset($u->role) && in_array(strtolower((string)$u->role), ['admin','administrator','superadmin','owner'], true)) ||
        (method_exists($u, 'isAdmin') && $u->isAdmin()) ||
        (\Illuminate\Support\Facades\Gate::allows('admin')) ||
        (\Illuminate\Support\Facades\Gate::allows('manage-users')) ||
        ($u->can('admin') ?? false) ||
        ($u->can('manage-users') ?? false)
      );
    @endphp

    {{-- Users Management: always visible if routes exist; controller/policies can still restrict actions --}}
    @if (\Illuminate\Support\Facades\Route::has('settings.users.index'))
      <a href="{{ route('settings.users.index') }}" class="block px-3 py-2 rounded hover:bg-gray-100">Users Management</a>
    @endif

    {{-- IMAP Settings: admin-only in the sidebar --}}
    @if ($isAdmin && \Illuminate\Support\Facades\Route::has('settings.imap.edit'))
      <a href="{{ route('settings.imap.edit') }}" class="block px-3 py-2 rounded hover:bg-gray-100">IMAP Settings</a>
    @endif
  </div>
</div>
BLADE

# Warm caches
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "Sidebar restored: Users Management visible; IMAP shows for admin only."
