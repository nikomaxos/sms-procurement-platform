#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

ROUTES="routes/web.php"
TS="$(date +%F_%H-%M-%S)"

echo "==> Backing up routes to $ROUTES.bak.$TS"
cp -a "$ROUTES" "$ROUTES.bak.$TS"

echo "==> Writing a clean routes/web.php (keeps your existing pages + adds Users resource)"
cat > "$ROUTES" <<'PHP'
<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\ImapSettingsController;
use App\Http\Controllers\DropDownController;

Route::get('/', function () {
    return view('welcome');
});

// Authenticated area
Route::middleware(['auth'])->group(function () {
    // Dashboard
    Route::get('/dashboard', function () { return view('dashboard'); })->name('dashboard');

    // Settings hub + subpages
    Route::get('/settings', [SettingsController::class, 'index'])->name('settings.index');
    Route::get('/settings/dropdowns', [DropDownController::class, 'index'])->name('settings.dropdowns.index');
    Route::get('/settings/imap', [ImapSettingsController::class, 'edit'])->name('settings.imap.edit');

    // Profile management (if Breeze profile controller exists)
    if (class_exists(ProfileController::class)) {
        Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
        Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
        Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
    }
});

if (file_exists(__DIR__.'/auth.php')) {
    require __DIR__.'/auth.php';
}

// Change Password (auth)
Route::middleware('auth')->group(function () {
    Route::get('/password/change', [\App\Http\Controllers\Auth\PasswordChangeController::class, 'edit'])
        ->name('password.change');
    Route::put('/password/change', [\App\Http\Controllers\Auth\PasswordChangeController::class, 'update'])
        ->name('password.change.update');
});

// Users Management (admin-only via controller middleware implemented in controller)
Route::middleware(['auth'])->prefix('settings')->name('settings.')->group(function () {
    Route::resource('users', \App\Http\Controllers\Settings\UsersManagementController::class)
        ->except(['show'])
        ->names('users');
});
PHP

echo "==> Ensure controller exists (admin-only guard inside)"
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

echo "==> Clear route cache and print users routes"
$DC exec -T app php artisan route:clear
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan route:list | awk 'NR<=5 || /settings\\/users/'

echo "==> Done. Open /settings/users (admin)."
