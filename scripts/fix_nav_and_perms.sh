#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR on line $LINENO: $BASH_COMMAND" >&2' ERR

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

views_dir="resources/views"
layout="$views_dir/layouts/app.blade.php"
partial_dir="$views_dir/partials"
partial="$partial_dir/nav.blade.php"

mkdir -p "$partial_dir"

# --- 1) Write a clean, CSP-safe Tailwind navbar with a Settings dropdown ---
cat > "$partial" <<'BLADE'
<nav class="bg-white border-b">
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <div class="flex h-14 items-center justify-between">
      <div class="flex items-center gap-6">
        <a href="{{ url('/') }}" class="font-semibold text-gray-800">SMS Suppliers</a>

        <a href="{{ url('/dashboard') }}"
           class="text-sm {{ request()->is('dashboard') ? 'text-blue-600' : 'text-gray-700 hover:text-gray-900' }}">
          Dashboard
        </a>

        <div class="relative group">
          <button type="button" class="inline-flex items-center gap-2 text-sm text-gray-700 group-hover:text-gray-900">
            <span>Settings</span>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.17l3.71-3.94a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd"/>
            </svg>
          </button>
          <div class="absolute left-0 z-50 hidden group-hover:block bg-white shadow rounded-md mt-2 min-w-56 py-1">
            <a href="{{ route('settings.index') }}"
               class="block px-4 py-2 text-sm {{ request()->routeIs('settings.index') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
              Settings Home
            </a>
            <a href="{{ url('/settings/dropdowns') }}"
               class="block px-4 py-2 text-sm {{ request()->is('settings/dropdowns*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
              Drop Down Menus
            </a>
            <a href="{{ url('/settings/imap') }}"
               class="block px-4 py-2 text-sm {{ request()->is('settings/imap*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
              IMAP Settings
            </a>
            <a href="{{ url('/settings/users') }}"
               class="block px-4 py-2 text-sm {{ request()->is('settings/users*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
              Users Management
            </a>
          </div>
        </div>
      </div>

      <div class="flex items-center gap-3">
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
</nav>
BLADE

# --- 2) Ensure the partial is included once in the layout (do not duplicate) ---
if [ -f "$layout" ] && ! grep -q "@include('partials.nav')" "$layout"; then
  if grep -q "<body" "$layout"; then
    awk 'BEGIN{done=0}
      /<body[^>]*>/ && !done { print; print "    @include('\''partials.nav'\'')"; done=1; next }
      { print }' "$layout" > "${layout}.tmp" && mv "${layout}.tmp" "$layout"
  elif grep -q "@yield('content')" "$layout"; then
    sed -i "0,/@yield('content')/s//@include('partials.nav')\\n\\n@yield('content')/" "$layout"
  else
    sed -i "1s;^;@include('partials.nav')\\n\\n;" "$layout"
  fi
fi

# --- 3) Fix perms INSIDE container and clear/cache views so Blade can compile ---
# pick compose
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  echo "ERROR: docker compose not found"; exit 1
fi

$DC exec -T app sh -lc '
  mkdir -p storage/framework/{cache,sessions,views} bootstrap/cache storage/logs &&
  chown -R www-data:www-data storage bootstrap/cache &&
  chmod -R 775 storage bootstrap/cache
'

$DC exec -T -w /var/www/html app php artisan optimize:clear || true
$DC exec -T -w /var/www/html app php artisan view:clear || true
$DC exec -T -w /var/www/html app php artisan config:cache
$DC exec -T -w /var/www/html app php artisan route:cache || true
$DC exec -T -w /var/www/html app php artisan view:cache  || true

echo "==> Fixed nav & permissions. Try /settings and the Settings dropdown again."
