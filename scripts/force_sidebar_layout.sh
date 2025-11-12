#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

VIEWS="resources/views"
LAYOUT="$VIEWS/layouts/app.blade.php"
PARTIALS="$VIEWS/partials"
TOPBAR="$PARTIALS/topbar.blade.php"
SIDEBAR="$PARTIALS/sidebar.blade.php"
TS="$(date +%F_%H-%M-%S)"

mkdir -p "$PARTIALS"

echo "==> Backup current layout (if present)"
[ -f "$LAYOUT" ] && cp -a "$LAYOUT" "${LAYOUT}.bak.${TS}" || true

#####################################
# Top bar (brand left, user right)
#####################################
cat > "$TOPBAR" <<'BLADE'
<header class="w-full border-b bg-white">
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <div class="h-14 flex items-center justify-between">
      <a href="{{ url('/') }}" class="font-semibold text-gray-800">SMS Suppliers</a>
      <div class="flex items-center gap-4">
        @auth
          <span class="text-sm text-gray-600">{{ auth()->user()->name }}</span>
          <form method="POST" action="{{ route('logout') }}">
            @csrf
            <button class="text-sm text-gray-700 hover:text-gray-900">Logout</button>
          </form>
        @endauth
        @guest
          <a href="{{ route('login') }}" class="text-sm text-gray-700 hover:text-gray-900">Login</a>
        @endguest
      </div>
    </div>
  </div>
</header>
BLADE

#############################################
# Sidebar (left, hover-expand Settings)
#############################################
cat > "$SIDEBAR" <<'BLADE'
<aside class="w-64 shrink-0 border-r bg-white min-h-screen">
  <nav class="py-4">
    <ul class="px-2 space-y-1 text-sm">
      <li>
        <a href="{{ url('/dashboard') }}"
           class="block px-3 py-2 rounded {{ request()->is('dashboard') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
          Dashboard
        </a>
      </li>

      <li class="relative group">
        <div class="flex items-center justify-between px-3 py-2 rounded cursor-default
                    {{ request()->is('settings*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 group-hover:bg-gray-50' }}">
          <span>Settings</span>
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 opacity-70" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.17l3.71-3.94a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd"/>
          </svg>
        </div>
        <div class="absolute left-0 top-full z-50 hidden group-hover:block bg-white border rounded-md mt-1 min-w-56 py-1 shadow">
          <a href="{{ route('settings.index') }}"
             class="block px-4 py-2 text-sm {{ request()->is('settings') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
            Settings Home
          </a>
          <a href="{{ route('settings.dropdowns.index') }}"
             class="block px-4 py-2 text-sm {{ request()->is('settings/dropdowns*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
            Drop Down Menus
          </a>
          <a href="{{ route('settings.imap.edit') }}"
             class="block px-4 py-2 text-sm {{ request()->is('settings/imap*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
            IMAP Settings
          </a>
          <a href="{{ route('settings.users.index') }}"
             class="block px-4 py-2 text-sm {{ request()->is('settings/users*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
            Users Management
          </a>
        </div>
      </li>
    </ul>
  </nav>
</aside>
BLADE

######################################################################
# Anonymous component layout used by <x-app-layout> for ALL pages
# - top bar
# - left sidebar
# - main content supports @yield('content') (preferred) OR $slot fallback
# - keeps @vite includes (your repo has Vite/Tailwind files)
######################################################################
cat > "$LAYOUT" <<'BLADE'
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ config('app.name', 'Laravel') }}</title>
    @vite(['resources/css/app.css','resources/js/app.js'])
  </head>
  <body class="antialiased bg-gray-50">
    @include('partials.topbar')

    <div class="flex">
      @include('partials.sidebar')

      <main class="flex-1 min-h-screen">
        @isset($header)
          <header class="bg-white border-b">
            <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-4">
              {{ $header }}
            </div>
          </header>
        @endisset

        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6">
          @hasSection('content')
            @yield('content')
          @else
            {{ $slot ?? '' }}
          @endif
        </div>
      </main>
    </div>
  </body>
</html>
BLADE

echo "==> Fixing storage/bootstrap permissions inside container (for Blade cache)"
$DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rwX storage bootstrap/cache'

echo "==> Clearing and caching views/config"
$DC exec -T app php artisan view:clear
$DC exec -T app php artisan optimize

echo "==> (Optional) Build assets: set BUILD_ASSETS=1 to run vite build via node container"
if [ "${BUILD_ASSETS:-0}" = "1" ]; then
  $DC exec -T node sh -lc 'npm ci && npm run build'
fi

echo "==> Done. Refresh the app in the browser."
