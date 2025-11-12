#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(pwd)"
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

say(){ printf "==> %s\n" "$*"; }

# 1) AppLayout component class (maps <x-app-layout> to view 'layouts.app')
mkdir -p app/View/Components
cat > app/View/Components/AppLayout.php <<'PHP'
<?php
namespace App\View\Components;

use Illuminate\View\Component;
use Illuminate\View\View;

class AppLayout extends Component {
    public function render(): View {
        return view('layouts.app');
    }
}
PHP
say "Wrote: app/View/Components/AppLayout.php"

# 2) Pure component layout (no @yield): uses $slot + optional $header
mkdir -p resources/views/layouts
cat > resources/views/layouts/app.blade.php <<'BLADE'
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ config('app.name', 'Laravel') }}</title>

    <link rel="preconnect" href="https://fonts.bunny.net">
    <link href="https://fonts.bunny.net/css?family=figtree:400,500,600&display=swap" rel="stylesheet" />
    @vite(['resources/css/app.css', 'resources/js/app.js'])
  </head>
  <body class="font-sans antialiased">
    @includeIf('partials.settings_nav')

    <div class="min-h-screen bg-gray-100">
      @includeIf('layouts.navigation')

      @if (isset($header))
        <header class="bg-white shadow">
          <div class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
            {{ $header }}
          </div>
        </header>
      @endif

      <main>
        {{ $slot }}
      </main>
    </div>
  </body>
</html>
BLADE
say "Wrote: resources/views/layouts/app.blade.php"

# 3) Convert Settings views to <x-app-layout> (component style)
mkdir -p resources/views/settings/{dropdowns,imap,users}

cat > resources/views/settings/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Settings</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <a href="{{ route('settings.dropdowns.index') }}" class="block rounded-lg border p-6 bg-white hover:bg-gray-50">
        <div class="text-lg font-semibold">Drop Down Menus</div>
        <div class="text-gray-500 text-sm mt-1">Manage option lists used across the app.</div>
      </a>
      <a href="{{ route('settings.imap.edit') }}" class="block rounded-lg border p-6 bg-white hover:bg-gray-50">
        <div class="text-lg font-semibold">IMAP Settings</div>
        <div class="text-gray-500 text-sm mt-1">Configure mailbox polling (minutes) and folders.</div>
      </a>
      <a href="{{ route('settings.users.index') }}" class="block rounded-lg border p-6 bg-white hover:bg-gray-50">
        <div class="text-lg font-semibold">Users Management</div>
        <div class="text-gray-500 text-sm mt-1">List users (read-only stub; enhance later).</div>
      </a>
    </div>
  </div>
</x-app-layout>
BLADE
say "Wrote: resources/views/settings/index.blade.php"

cat > resources/views/settings/dropdowns/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Drop Down Menus</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="rounded-lg border bg-white p-6">
      <p class="text-gray-600">Placeholder page. We will wire CRUD here.</p>
    </div>
  </div>
</x-app-layout>
BLADE
say "Wrote: resources/views/settings/dropdowns/index.blade.php"

cat > resources/views/settings/imap/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">IMAP Settings</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="rounded-lg border bg-white p-6">
      <p class="text-gray-600">Placeholder IMAP form. (Existing implementation will be re-mounted here.)</p>
    </div>
  </div>
</x-app-layout>
BLADE
say "Wrote: resources/views/settings/imap/edit.blade.php"

cat > resources/views/settings/users/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Users Management</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="rounded-lg border bg-white p-6 overflow-x-auto">
      <p class="text-gray-600 mb-4">Stub table (read-only). Replace with real management later.</p>
      <table class="min-w-full border">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left text-sm font-semibold">ID</th>
            <th class="px-3 py-2 text-left text-sm font-semibold">Name</th>
            <th class="px-3 py-2 text-left text-sm font-semibold">Email</th>
            <th class="px-3 py-2 text-left text-sm font-semibold">Created</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          @foreach(\App\Models\User::select('id','name','email','created_at')->orderBy('id')->limit(20)->get() as $u)
            <tr>
              <td class="px-3 py-2 text-sm">{{ $u->id }}</td>
              <td class="px-3 py-2 text-sm">{{ $u->name }}</td>
              <td class="px-3 py-2 text-sm">{{ $u->email }}</td>
              <td class="px-3 py-2 text-sm">{{ $u->created_at }}</td>
            </tr>
          @endforeach
        </tbody>
      </table>
    </div>
  </div>
</x-app-layout>
BLADE
say "Wrote: resources/views/settings/users/index.blade.php"

# 4) Ensure routes exist (safe re-patch)
ROUTES=routes/web.php
grep -q "settings.dropdowns.index" "$ROUTES" || cat >> "$ROUTES" <<'PHP'

Route::middleware(['auth'])->group(function () {
    Route::get('/settings', [\App\Http\Controllers\SettingsController::class, 'index'])->name('settings.index');
    Route::get('/settings/dropdowns', [\App\Http\Controllers\DropDownController::class, 'index'])->name('settings.dropdowns.index');
    Route::get('/settings/imap', [\App\Http\Controllers\ImapSettingsController::class, 'edit'])->name('settings.imap.edit');
    Route::get('/settings/users', [\App\Http\Controllers\UserManagementController::class, 'index'])->name('settings.users.index');
});
PHP
say "Routes ensured in routes/web.php"

# 5) Fix storage perms and clear caches inside container
$DC exec -T app sh -lc '
  set -e
  umask 000
  mkdir -p storage/framework/{views,cache,sessions} storage/logs bootstrap/cache
  chown -R www-data:www-data storage bootstrap/cache || true
  chmod -R 0777 storage bootstrap/cache
  rm -f storage/framework/views/* || true
'
$DC exec -T -w /var/www/html app php artisan optimize:clear
$DC exec -T -w /var/www/html app php artisan view:cache || true
$DC exec -T -w /var/www/html app php artisan route:cache || true
$DC exec -T -w /var/www/html app php artisan config:cache || true

# 6) Show routes summary
$DC exec -T -w /var/www/html app php artisan route:list | grep -E 'settings|dashboard' || true
say "Done. Open /settings and subpages while logged in."
