#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

CTR="app/Http/Controllers/Settings/UsersManagementController.php"
SIDEBAR="resources/views/partials/sidebar.blade.php"
TOPBAR="resources/views/partials/topbar.blade.php"

echo "==> 1) Overwrite UsersManagementController with safe redirect for non-admin"
mkdir -p "$(dirname "$CTR")"
cat > "$CTR" <<'PHP'
<?php

namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class UsersManagementController extends Controller
{
    public function __construct() {
        $this->middleware('auth');
        $this->middleware(function ($request, $next) {
            $u = $request->user();
            if (!($u && $u->role === 'admin')) {
                // Redirect to Settings (silent deny; no 403 page)
                return redirect()->route('settings.index')->with('status', 'not-authorized');
            }
            return $next($request);
        });
    }

    public function index() {
        $users = User::orderByDesc('id')->paginate(20);
        return view('settings.users.index', compact('users'));
    }

    public function create() {
        return view('settings.users.create');
    }

    public function store(Request $request) {
        $data = $request->validate([
            'name' => ['required','string','max:255'],
            'email' => ['required','email','max:255','unique:users,email'],
            'role' => ['required', Rule::in(['admin','standard'])],
            'password' => ['required','confirmed', Password::defaults()],
        ]);
        $user = new User();
        $user->name = $data['name'];
        $user->email = $data['email'];
        $user->role = $data['role'];
        $user->password = Hash::make($data['password']);
        $user->save();
        return redirect()->route('settings.users.index')->with('status', 'user-created');
    }

    public function edit(User $user) {
        return view('settings.users.edit', compact('user'));
    }

    public function update(Request $request, User $user) {
        $data = $request->validate([
            'name' => ['required','string','max:255'],
            'email' => ['required','email','max:255', Rule::unique('users','email')->ignore($user->id)],
            'role' => ['required', Rule::in(['admin','standard'])],
            'password' => ['nullable','confirmed', Password::defaults()],
        ]);
        $user->name = $data['name'];
        $user->email = $data['email'];
        $user->role = $data['role'];
        if (!empty($data['password'])) {
            $user->password = Hash::make($data['password']);
        }
        $user->save();
        return redirect()->route('settings.users.index')->with('status', 'user-updated');
    }

    public function destroy(Request $request, User $user) {
        if ($request->user()->id === $user->id) {
            return back()->withErrors(['delete' => "You can't delete your own account while logged in."]);
        }
        $user->delete();
        return redirect()->route('settings.users.index')->with('status', 'user-deleted');
    }
}
PHP

echo "==> 2) Guard Users Management link in sidebar (hide for non-admins)"
if [ -f "$SIDEBAR" ]; then
  cp -a "$SIDEBAR" "$SIDEBAR.bak.$(date +%F_%H-%M-%S)"
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
  echo "   -> Sidebar not found ($SIDEBAR); skipping"
fi

echo "==> 3) Write robust topbar dropdown that stays open while hovering"
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

            <!-- Use same positioned wrapper so there is no gap between button and menu -->
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
$DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rw storage bootstrap/cache'
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan view:cache || true
$DC exec -T app php artisan route:cache || true

echo "==> Done. Behaviour:"
echo "   • Standard user: Users Management link hidden; direct URL redirects to /settings."
echo "   • Top-right dropdown: stays open while hovering; you can click Change password / Logout."
