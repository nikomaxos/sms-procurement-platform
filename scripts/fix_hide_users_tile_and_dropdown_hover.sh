#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

SETTINGS_IDX="resources/views/settings/index.blade.php"
TOPBAR="resources/views/partials/topbar.blade.php"

##############################################
# 1) Hide Users Management tile (non-admins)
##############################################
if [ -f "$SETTINGS_IDX" ]; then
  cp -a "$SETTINGS_IDX" "$SETTINGS_IDX.bak.$(date +%F_%H-%M-%S)"

  # Wrap the tile anchor that contains "Users Management" text — works for both route() and url()/href cases
  perl -0777 -i -pe '
    my $guard_start = q{@if(auth()->check() && auth()->user()?->role === '\''admin'\'')};
    my $guard_end   = q{@endif};

    # If it is already guarded near the users tile, do nothing
    if (/@if\(auth\(\)->check\(\) && auth\(\)->user\(\)\?->role === .admin.\)[\s\S]*Users\s+Management/s) {
      $_;
    } else {
      # 1) route("settings.users.index")
      s{
        (\s*<a[^>]*href="{{\s*route\(\s*'\Qsettings.users.index\E'\s*\)\s*}}".*?>.*?Users\s+Management.*?</a>)
      }{$guard_start\n$1\n$guard_end}igsx;

      # 2) url('/settings/users')
      s{
        (\s*<a[^>]*href="{{\s*url\(\s*'\Q/settings/users\E'\s*\)\s*}}".*?>.*?Users\s+Management.*?</a>)
      }{$guard_start\n$1\n$guard_end}igsx;

      # 3) direct href="/settings/users" (fallback)
      s{
        (\s*<a[^>]*href="\/settings\/users"[^>]*>.*?Users\s+Management.*?<\/a>)
      }{$guard_start\n$1\n$guard_end}igsx;
    }
    $_;
  ' "$SETTINGS_IDX"
else
  echo "WARN: $SETTINGS_IDX not found (skipping tile guard)"
fi

########################################################
# 2) Rebuild top-right dropdown (visible, no gap flicker)
########################################################
mkdir -p "$(dirname "$TOPBAR")"
cat > "$TOPBAR" <<'BLADE'
<header class="w-full border-b bg-white relative z-[999]">
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <div class="h-14 flex items-center justify-between">
      <a href="{{ url('/') }}" class="font-semibold text-gray-800">SMS Suppliers</a>

      <div class="flex items-center gap-4">
        @auth
          <!-- Keep button and menu inside the same .group; remove vertical gap (no mt) to avoid hover drop -->
          <div class="relative inline-block text-left group">
            <button type="button"
                    class="inline-flex items-center gap-2 text-sm text-gray-700 hover:text-gray-900 focus:outline-none"
                    aria-haspopup="true" aria-expanded="false">
              <span>{{ auth()->user()->name }}</span>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.17l3.71-3.94a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd"/>
              </svg>
            </button>

            <!-- Visible menu: solid bg, border, shadow; opens on hover or focus-within; NO margin-gap -->
            <div class="absolute right-0 top-full w-56 rounded-md border bg-white shadow-lg
                        hidden group-hover:block group-focus-within:block z-[1000]">
              <!-- Inner padding creates visual spacing without creating a hover gap -->
              <div class="py-2">
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

########################################################
# 3) Rebuild caches so Blade re-renders the new views
########################################################
$DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rw storage bootstrap/cache'
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan view:clear || true
$DC exec -T app php artisan view:cache || true
$DC exec -T app php artisan route:cache || true

echo "==> Done."
echo "   • Settings page: Users tile hidden for non-admins."
echo "   • Top-right dropdown: white, bordered, shadowed; opens on hover & stays open (no gap)."
