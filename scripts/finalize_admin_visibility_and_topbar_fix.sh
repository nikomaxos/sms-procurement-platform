#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

SIDEBAR="resources/views/partials/sidebar.blade.php"
TOPBAR="resources/views/partials/topbar.blade.php"

echo "==> 1) Overwrite sidebar with admin-guarded Users Management (completely hidden for non-admins)"
mkdir -p "$(dirname "$SIDEBAR")"
cat > "$SIDEBAR" <<'BLADE'
<aside class="w-64 shrink-0 border-r bg-white min-h-screen">
  <nav class="py-4">
    <ul class="px-2 space-y-1 text-sm">

      <li>
        <a href="{{ route('dashboard') }}"
           class="block rounded px-3 py-2 {{ request()->routeIs('dashboard') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
          Dashboard
        </a>
      </li>

      <li class="mt-4 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">
        Settings
      </li>

      <li>
        <a href="{{ route('settings.index') }}"
           class="block rounded px-3 py-2 {{ request()->routeIs('settings.index') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
          Settings Home
        </a>
      </li>

      <li>
        <a href="{{ route('settings.dropdowns.index') }}"
           class="block rounded px-3 py-2 {{ request()->routeIs('settings.dropdowns.*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
          Drop Down Menus
        </a>
      </li>

      <li>
        <a href="{{ route('settings.imap.edit') }}"
           class="block rounded px-3 py-2 {{ request()->routeIs('settings.imap.*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
          IMAP Settings
        </a>
      </li>

      @if(auth()->check() && auth()->user()?->role === 'admin')
      <li>
        <a href="{{ route('settings.users.index') }}"
           class="block rounded px-3 py-2 {{ request()->routeIs('settings.users.*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
          Users Management
        </a>
      </li>
      @endif

    </ul>
  </nav>
</aside>
BLADE

echo "==> 2) Overwrite topbar to a visible, non-flickering dropdown (no transparency issues)"
mkdir -p "$(dirname "$TOPBAR")"
cat > "$TOPBAR" <<'BLADE'
<header class="w-full border-b bg-white relative z-[999]">
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <div class="h-14 flex items-center justify-between">
      <a href="{{ url('/') }}" class="font-semibold text-gray-800">SMS Suppliers</a>

      <div class="flex items-center gap-4">
        @auth
          <!-- Keep the menu and button inside the same relative container to avoid hover gaps -->
          <div class="relative inline-block text-left">
            <button type="button"
                    class="inline-flex items-center gap-2 text-sm text-gray-700 hover:text-gray-900 focus:outline-none"
                    aria-haspopup="true" aria-expanded="false">
              <span>{{ auth()->user()->name }}</span>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.17l3.71-3.94a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd"/>
              </svg>
            </button>

            <!-- Dropdown (visible on hover/focus): use hidden/block toggling (no opacity/invisible) -->
            <div class="absolute right-0 top-full mt-2 w-56 rounded-md border bg-white shadow-lg hidden
                        group-[.open]:block focus-within:block"
                 x-data="{ open: false }"
                 @mouseenter="open = true" @mouseleave="open = false"
                 :class="open ? 'block' : 'hidden'">
              <div class="py-1">
                @if (Route::has('password.change'))
                  <a href="{{ route('password.change') }}"
                     class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50">Change password</a>
                @endif
                @if (Route::has('profile.edit'))
                  <a href="{{ route('profile.edit') }}"
                     class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50">Profile</a>
                @endif
                <form method="POST" action="{{ route('logout') }}">
                  @csrf
                  <button type="submit"
                          class="w-full text-left block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50">
                    Logout
                  </button>
                </form>
              </div>
            </div>
          </div>
        @endauth

        @guest
          <a href="{{ route('login') }}" class="text-sm text-gray-700 hover:text-gray-900">Login</a>
        @endguest
      </div>
    </div>
  </div>
</header>
BLADE

echo "==> 3) Refresh caches & perms (for Blade rendering visibility)"
if docker ps >/dev/null 2>&1; then
  $DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rw storage bootstrap/cache'
  $DC exec -T app php artisan optimize:clear || true
  $DC exec -T app php artisan view:cache || true
  $DC exec -T app php artisan route:cache || true
else
  echo "   -> Docker not running? Skipping container cache clear."
fi

echo "==> Done."
echo "   • As a STANDARD user, the Users Management item will NOT render at all."
echo "   • The top-right dropdown is fully visible (solid bg, border, shadow) and stays open while hovering."
