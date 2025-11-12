#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

SIDEBAR="resources/views/partials/sidebar.blade.php"
TOPBAR="resources/views/partials/topbar.blade.php"
CTR="app/Http/Controllers/Settings/UsersManagementController.php"

echo "==> 1) Controller: standard users are redirected (no 403 page shown)"
# Replace the middleware closure body to do a redirect to settings.index
if [ -f "$CTR" ]; then
  perl -0777 -i -pe "
    s{
      \\$this->middleware\\(function\\s*\\(\\$request,\\s*\\$next\\)\\s*\\{[\\s\\S]*?\\}\\);
    }{
      \$this->middleware(function (\$request, \$next) {
          \$u = \$request->user();
          if (!(\$u && \$u->role === 'admin')) {
              return redirect()->route('settings.index')->with('status', 'not-authorized');
          }
          return \$next(\$request);
      });
    }sx
  " "$CTR"
else
  echo "   -> Controller not found ($CTR). Aborting."
  exit 1
fi

echo "==> 2) Sidebar: hide Users Management for non-admins"
if [ -f "$SIDEBAR" ]; then
  cp -a "$SIDEBAR" "$SIDEBAR.bak.$(date +%F_%H-%M-%S)"
  # Wrap Users Management link with admin guard if not already guarded
  perl -0777 -i -pe '
    my $guard = q{@if(auth()->check() && auth()->user()?->role === '\''admin'\'')};
    my $end   = q{@endif};
    if (!/@if\(auth\(\)->check\(\) && auth\(\)->user\(\)\?->role === .admin.\)[\s\S]*route\(.\Qsettings.users.index\E./s) {
      s{
        (\s*<a\s+href="{{\s*route\(\s*'\Qsettings.users.index\E'\s*\)\s*}}".*?>.*?Users\s+Management.*?</a>)
      }{$guard\n$1\n$end}igsx;
    }
    $_;
  ' "$SIDEBAR" || true
else
  echo "   -> Sidebar file not found ($SIDEBAR)."
fi

echo "==> 3) Topbar: robust hover/focus dropdown (no disappearing on mouse move)"
mkdir -p "$(dirname "$TOPBAR")"
cat > "$TOPBAR" <<'BLADE'
<header class="w-full border-b bg-white">
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <div class="h-14 flex items-center justify-between">
      <a href="{{ url('/') }}" class="font-semibold text-gray-800">SMS Suppliers</a>

      <div class="flex items-center gap-4">
        @auth
          <div class="relative inline-block text-left group">
            <button type="button"
                    class="inline-flex items-center gap-2 text-sm text-gray-700 hover:text-gray-900 focus:outline-none"
                    aria-haspopup="true" aria-expanded="false">
              <span>{{ auth()->user()->name }}</span>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.17l3.71-3.94a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd"/>
              </svg>
            </button>

            <!-- Dropdown: stays open when moving mouse into it (same relative wrapper) -->
            <div class="absolute right-0 top-full mt-2 w-52 rounded-md border bg-white shadow-lg
                        invisible opacity-0 translate-y-1 transition
                        group-hover:visible group-hover:opacity-100 group-hover:translate-y-0
                        focus-within:visible focus-within:opacity-100 focus-within:translate-y-0 z-50">
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

echo "==> 4) Fix writable dirs & refresh caches"
if docker ps >/dev/null 2>&1; then
  $DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rw storage bootstrap/cache'
  $DC exec -T app php artisan optimize:clear || true
  $DC exec -T app php artisan view:cache || true
  $DC exec -T app php artisan route:cache || true
else
  echo "   -> Docker not running? Skipping container cache clear."
fi

echo "==> Done. Test:"
echo "   • Login as STANDARD user: Users Management link is hidden; hitting /settings/users redirects to /settings."
echo "   • Hover top-right user menu: menu stays open so you can click Change password / Logout."
