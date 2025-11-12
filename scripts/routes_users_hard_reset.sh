#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

ROUTES="routes/web.php"
TS="$(date +%F_%H-%M-%S)"

echo "==> Backup routes to $ROUTES.bak.$TS"
cp -a "$ROUTES" "$ROUTES.bak.$TS"

echo "==> Strip broken / duplicated Users Management route blocks"
awk '
  BEGIN{in_admin=0; in_auto=0}
  {
    line=$0

    # Strip any previous AUTO block between our markers
    if (line ~ /BEGIN USERS MANAGEMENT \(AUTO\)/) {in_auto=1; next}
    if (in_auto && line ~ /END USERS MANAGEMENT \(AUTO\)/) {in_auto=0; next}
    if (in_auto) next

    # Strip any legacy block that starts with the comment and ends at a closing "});"
    if (line ~ /^ *\/\/ *Users Management \(admin-only via controller middleware\)/) {in_admin=1; next}
    if (in_admin && line ~ /\}\);\s*$/) {in_admin=0; next}
    if (in_admin) next

    # Strip orphaned chain lines that caused the ParseError
    if (line ~ /->except\(.*\)\s*; *$/) next
    if (line ~ /->names\(['"]users['"]\)\s*; *$/) next

    # Strip any single-line legacy references
    if (line ~ /UserManagementController/) next
    if (line ~ /settings(\/|\.)users/) next

    print line
  }
' "$ROUTES.bak.$TS" > "$ROUTES.tmp"

# Compact accidental blank runs
awk 'NR==1{print; next} { if (NF==0 && last_blank) next; print; last_blank=(NF==0) }' "$ROUTES.tmp" > "$ROUTES"

rm -f "$ROUTES.tmp"

echo "==> Ensure controller file exists (admin-only guard)"
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

echo "==> Append a single canonical resource block"
cat >> "$ROUTES" <<'PHP'

// ==== BEGIN USERS MANAGEMENT (AUTO) ====
Route::middleware(['auth'])->prefix('settings')->name('settings.')->group(function () {
    Route::resource('users', \App\Http\Controllers\Settings\UsersManagementController::class)
        ->except(['show'])
        ->names('users');
});
// ==== END USERS MANAGEMENT (AUTO) ====
PHP

echo "==> Clear caches and list routes"
$DC exec -T app php artisan route:clear
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan route:list | sed -n '1,5p; /settings\\/users/p'

echo "==> Done. Open /settings/users (admin)."
