#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

views_dir="resources/views"
layout="$views_dir/layouts/app.blade.php"
partial_dir="$views_dir/partials"
partial="$partial_dir/nav.blade.php"

ts="$(date +%F_%H-%M-%S)"

# 1) Ensure partials dir
mkdir -p "$partial_dir"

# 2) Write/overwrite a minimal, CSP-safe Tailwind navbar with a Settings dropdown
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
            <a href="{{ url('/settings') }}"
               class="block px-4 py-2 text-sm {{ request()->is('settings') ? 'bg-gray-100 text-gray-900' : 'text-gray-700 hover:bg-gray-50' }}">
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

# 3) Backup layout once, then ensure it includes the navbar partial before @yield('content')
if [ -f "$layout" ]; then
  cp -a "$layout" "${layout}.bak.${ts}"
else
  echo "ERROR: Layout not found at $layout"; exit 1
fi

# Only insert once
if ! grep -q "@include('partials.nav')" "$layout"; then
  # Insert the include after the opening <body ...> line, else before @yield('content')
  if grep -n "<body" "$layout" >/dev/null 2>&1; then
    awk '
      BEGIN{done=0}
      /<body[^>]*>/ && done==0 { print; print "    @include('\''partials.nav'\'')"; done=1; next }
      { print }
    ' "$layout" > "${layout}.tmp"
    mv "${layout}.tmp" "$layout"
  elif grep -n "@yield('content')" "$layout" >/dev/null 2>&1; then
    sed -i "0,/@yield('content')/s//@include('partials.nav')\\n\\n@yield('content')/" "$layout"
  else
    # Fallback: append at top of file
    sed -i "1s;^;@include('partials.nav')\\n\\n;" "$layout"
  fi
fi

echo "==> Settings menu aligned: navbar partial at $partial, included in $layout"
