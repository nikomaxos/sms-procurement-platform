#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

ROUTES="routes/web.php"
TS="$(date +%F_%H-%M-%S)"

echo "==> 0) Backup routes"
cp -a "$ROUTES" "$ROUTES.bak.$TS"

echo "==> 1) Remove orphaned chains and legacy lines"
# Remove any standalone ->except(['show']); and ->names('users'); lines
perl -0777 -i -pe "s/^[\\t ]*->except\\(\\s*\\['show'\\]\\s*\\)\\s*;\\s*\\n//mg" "$ROUTES"
perl -0777 -i -pe "s/^[\\t ]*->names\\(\\s*'users'\\s*\\)\\s*;\\s*\\n//mg" "$ROUTES"
# Remove any ad-hoc routes pointing at (old) UserManagementController lines
perl -0777 -i -pe "s/^.*UserManagementController.*\\n//mg" "$ROUTES"

echo "==> 2) Ensure correct UsersManagementController file exists"
mkdir -p app/Http/Controllers/Settings
cat > app/Http/Controllers/Settings/UsersManagementController.php <<'PHP'
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
            abort_unless($u && $u->role === 'admin', 403);
            return $next($request);
        });
    }

    public function index() {
        $users = User::orderByDesc('id')->paginate(20);
        return view('settings.users.index', compact('users'));
    }

    public function create() { return view('settings.users.create'); }

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

    public function edit(User $user) { return view('settings.users.edit', compact('user')); }

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

echo "==> 3) Append canonical resource block if missing"
if ! grep -q "UsersManagementController::class" "$ROUTES"; then
  cat >> "$ROUTES" <<'PHP'

// Users Management (admin-only via controller middleware)
Route::middleware(['auth'])->prefix('settings')->name('settings.')->group(function () {
    Route::resource('users', \App\Http\Controllers\Settings\UsersManagementController::class)
        ->except(['show'])
        ->names('users');
});
PHP
fi

echo "==> 4) Clear caches & show routes"
$DC exec -T app php artisan route:clear
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan route:list | sed -n '1,5p; /settings\\/users/p'

echo "==> Done. Reload /settings/users"
