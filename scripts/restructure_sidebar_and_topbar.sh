#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# Compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

views="resources/views"
layout="$views/layouts/app.blade.php"
partials="$views/partials"
topbar="$partials/topbar.blade.php"
sidebar="$partials/sidebar.blade.php"

ts="$(date +%F_%H-%M-%S)"
mkdir -p "$partials"

#####################################
# 1) Top bar (brand left, user right)
#####################################
cat > "$topbar" <<'BLADE'
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
# 2) Left vertical sidebar + hover submenus
#############################################
cat > "$sidebar" <<'BLADE'
<aside class="w-64 shrink-0 border-r bg-white min-h-screen">
  <nav class="py-4">
    <ul class="px-2 space-y-1 text-sm">
      <li>
        <a href="{{ url('/dashboard') }}"
           class="block rounded px-3 py-2 {{ request()->is('dashboard') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
          Dashboard
        </a>
      </li>

      <li class="relative group">
        <div class="flex items-center justify-between rounded px-3 py-2 text-gray-700 hover:bg-gray-50 cursor-default">
          <span>Settings</span>
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 opacity-70" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.17l3.71-3.94a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd"/></svg>
        </div>
        <ul class="ml-2 mt-1 hidden group-hover:block border-l pl-3 space-y-1">
          <li>
            <a href="{{ route('settings.index') }}"
               class="block rounded px-3 py-2 {{ request()->routeIs('settings.index') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
              Settings Home
            </a>
          </li>
          <li>
            <a href="{{ url('/settings/dropdowns') }}"
               class="block rounded px-3 py-2 {{ request()->is('settings/dropdowns*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
              Drop Down Menus
            </a>
          </li>
          <li>
            <a href="{{ url('/settings/imap') }}"
               class="block rounded px-3 py-2 {{ request()->is('settings/imap*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
              IMAP Settings
            </a>
          </li>
          <li>
            <a href="{{ url('/settings/users') }}"
               class="block rounded px-3 py-2 {{ request()->is('settings/users*') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
              Users Management
            </a>
          </li>
        </ul>
      </li>
    </ul>
  </nav>
</aside>
BLADE

####################################################
# 3) Backup layout and sanitize previous includes
####################################################
[ -f "$layout" ] || { echo "ERROR: layout not found at $layout"; exit 1; }
cp -a "$layout" "${layout}.bak.${ts}"

# Remove any old nav/sidebar includes to avoid duplicates
awk '
  /@include\('\''partials\.nav'\''\)/ { next }
  /@include\('\''partials\.sidebar'\''\)/ { next }
  { print }
' "$layout" > "${layout}.tmp" && mv "${layout}.tmp" "$layout"

# Ensure topbar include appears once right after <body>
if ! grep -q "@include('partials.topbar')" "$layout"; then
  if grep -q "<body" "$layout"; then
    awk '
      BEGIN{done=0}
      /<body[^>]*>/ && !done { print; print "    @include('\''partials.topbar'\'')"; done=1; next }
      { print }
    ' "$layout" > "${layout}.tmp" && mv "${layout}.tmp" "$layout"
  else
    sed -i "1s;^;@include('partials.topbar')\\n\\n;" "$layout"
  fi
fi

# Replace FIRST @yield('content') with sidebar+main wrapper (awk to avoid escaping hell)
if ! grep -q "@include('partials.sidebar')" "$layout"; then
  awk '
    BEGIN{done=0}
    {
      if(!done && $0 ~ /@yield\(['"'"']content['"'"']\)/){
        print "  <div class=\"flex\">";
        print "    @include('\''partials.sidebar'\'')";
        print "    <main class=\"flex-1 min-h-screen bg-white\">";
        print "      @yield('\''content'\'')";
        print "    </main>";
        print "  </div>";
        done=1; next
      }
      print
    }
  ' "$layout" > "${layout}.tmp" && mv "${layout}.tmp" "$layout"
fi

##########################################
# 4) Fix perms & rebuild caches in app
##########################################
$DC exec -T app sh -lc '
  mkdir -p storage/framework/{cache,sessions,views} bootstrap/cache storage/logs &&
  chown -R www-data:www-data storage bootstrap/cache &&
  chmod -R 775 storage bootstrap/cache
'
$DC exec -T -w /var/www/html app php artisan optimize:clear || true
$DC exec -T -w /var/www/html app php artisan config:cache
$DC exec -T -w /var/www/html app php artisan view:cache  || true
$DC exec -T -w /var/www/html app php artisan route:cache || true

echo "==> Restructure complete: topbar (user menu top-right) + left sidebar with hover Settings submenu."
echo "==> Backup saved: ${layout}.bak.${ts}"
