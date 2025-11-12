#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

VIEWS="resources/views"
SETTINGS_IDX="$VIEWS/settings/index.blade.php"
PARTIALS="$VIEWS/partials"
TOPBAR="$PARTIALS/topbar.blade.php"
LAY_APP="$VIEWS/layouts/app.blade.php"
COMP_APP="$VIEWS/components/app-layout.blade.php"
COMP_NEST="$VIEWS/components/layouts/app.blade.php"

mkdir -p "$PARTIALS"

echo "==> 1) Hide 'Users Management' tile on /settings for non-admins"
if [ -f "$SETTINGS_IDX" ]; then
  cp -a "$SETTINGS_IDX" "$SETTINGS_IDX.bak.$(date +%F_%H-%M-%S)"
  # Wrap the Users Management card (anchor) that points to route('settings.users.index')
  perl -0777 -i -pe '
    my $guard = "@if(auth()->check() && auth()->user()?->role === \x27admin\x27)";
    my $end   = "@endif";
    # If already guarded near the users tile, skip
    if (/@if\(auth\(\)->check\(\) && auth\(\)->user\(\)\?->role === .admin.\).*settings\.users\.index/s) {
      $_;
    } else {
      s{
        (\s*<a\s+href="{{\s*route\(\s*'\Qsettings.users.index\E'\s*\)\s*}}".*?</a>)
      }{$guard\n$1\n$end}igsx;
    }
  ' "$SETTINGS_IDX"
else
  echo "   -> $SETTINGS_IDX not found; skipping"
fi

echo "==> 2) Rebuild top-right user dropdown (pure CSS hover; visible, no flicker)"
cat > "$TOPBAR" <<'BLADE'
<header class="w-full border-b bg-white relative z-[999]">
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <div class="h-14 flex items-center justify-between">
      <a href="{{ url('/') }}" class="font-semibold text-gray-800">SMS Suppliers</a>

      <div class="flex items-center gap-4">
        @auth
          <!-- Keep trigger and menu in the same relative .group to avoid hover gaps -->
          <div class="relative inline-block text-left group">
            <button type="button"
                    class="inline-flex items-center gap-2 text-sm text-gray-700 hover:text-gray-900 focus:outline-none"
                    aria-haspopup="true" aria-expanded="false">
              <span>{{ auth()->user()->name }}</span>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.17l3.71-3.94a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd"/>
              </svg>
            </button>

            <!-- Visible menu: solid bg, border, shadow; opens on hover/focus -->
            <div class="absolute right-0 top-full mt-2 w-56 rounded-md border bg-white shadow-lg
                        hidden group-hover:block group-focus-within:block z-50">
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

echo "==> 3) Ensure topbar is included in layout/component files"
# Helper to inject @include after <body...> if not present
inject_include() {
  local file="$1"
  [ -f "$file" ] || return 0
  if ! grep -q "@include('partials.topbar')" "$file"; then
    cp -a "$file" "$file.bak.$(date +%F_%H-%M-%S)"
    perl -0777 -i -pe "s~(<body[^>]*>)~\\1\\n    @include('partials.topbar')~i" "$file"
  fi
}

inject_include "$LAY_APP"
inject_include "$COMP_APP"
inject_include "$COMP_NEST"

echo "==> 4) Fix perms & refresh caches (Blade needs to recompile)"
$DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rw storage bootstrap/cache'
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan view:cache || true
$DC exec -T app php artisan route:cache || true

echo "==> Done."
echo "   • Non-admins: Users tile hidden on /settings AND no Users link in sidebar."
echo "   • Top-right dropdown: visible (white background), stable on hover, clickable."
