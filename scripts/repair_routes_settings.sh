#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(pwd)"
ts="$(date +%F_%H-%M-%S)"

# --- Ensure base Controller (gives ->middleware()) ---
mkdir -p "$ROOT/app/Http/Controllers"
cat > "$ROOT/app/Http/Controllers/Controller.php" <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Foundation\Validation\ValidatesRequests;
use Illuminate\Routing\Controller as BaseController;

class Controller extends BaseController {
    use AuthorizesRequests, ValidatesRequests;
}
PHP

# --- Minimal Settings controllers (auth-protected) ---
cat > "$ROOT/app/Http/Controllers/SettingsController.php" <<'PHP'
<?php
namespace App\Http\Controllers;

class SettingsController extends Controller {
    public function __construct(){ $this->middleware('auth'); }
    public function index(){ return view('settings.index'); }
}
PHP

cat > "$ROOT/app/Http/Controllers/DropDownController.php" <<'PHP'
<?php
namespace App\Http\Controllers;

class DropDownController extends Controller {
    public function __construct(){ $this->middleware('auth'); }
    public function index(){ return view('settings.dropdowns.index'); }
}
PHP

cat > "$ROOT/app/Http/Controllers/ImapSettingsController.php" <<'PHP'
<?php
namespace App\Http\Controllers;

class ImapSettingsController extends Controller {
    public function __construct(){ $this->middleware('auth'); }
    public function edit(){ return view('settings.imap.edit'); }
}
PHP

cat > "$ROOT/app/Http/Controllers/UserManagementController.php" <<'PHP'
<?php
namespace App\Http\Controllers;

use App\Models\User;

class UserManagementController extends Controller {
    public function __construct(){ $this->middleware('auth'); }
    public function index(){
        $users = User::query()->select(['id','name','email','created_at'])->orderBy('id')->paginate(20);
        return view('settings.users.index', compact('users'));
    }
}
PHP

# --- Minimal views (CSP-safe). Only write if missing to avoid clobbering.
mkdir -p "$ROOT/resources/views/settings/dropdowns" \
         "$ROOT/resources/views/settings/imap" \
         "$ROOT/resources/views/settings/users"

[ -f "$ROOT/resources/views/settings/index.blade.php" ] || cat > "$ROOT/resources/views/settings/index.blade.php" <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="container" style="max-width:960px">
  <h1 class="mb-4">Settings</h1>
  <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px">
    <a href="{{ route('settings.dropdowns.index') }}" style="display:block;border:1px solid #e5e7eb;border-radius:12px;padding:16px;text-decoration:none">
      <h2 style="margin:0 0 8px 0;font-size:1.1rem">Drop Down Menus</h2>
      <p style="margin:0;color:#6b7280">Stub page.</p>
    </a>
    <a href="{{ route('settings.imap.edit') }}" style="display:block;border:1px solid #e5e7eb;border-radius:12px;padding:16px;text-decoration:none">
      <h2 style="margin:0 0 8px 0;font-size:1.1rem">IMAP Settings</h2>
      <p style="margin:0;color:#6b7280">Stub page.</p>
    </a>
    <a href="{{ route('settings.users.index') }}" style="display:block;border:1px solid #e5e7eb;border-radius:12px;padding:16px;text-decoration:none">
      <h2 style="margin:0 0 8px 0;font-size:1.1rem">Users Management</h2>
      <p style="margin:0;color:#6b7280">Basic list.</p>
    </a>
  </div>
</div>
@endsection
BLADE

[ -f "$ROOT/resources/views/settings/dropdowns/index.blade.php" ] || cat > "$ROOT/resources/views/settings/dropdowns/index.blade.php" <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="container" style="max-width:960px">
  <h1 class="mb-3">Drop Down Menus</h1>
  <p>Placeholder—CRUD later.</p>
  <a href="{{ route('settings.index') }}">← Back</a>
</div>
@endsection
BLADE

[ -f "$ROOT/resources/views/settings/imap/edit.blade.php" ] || cat > "$ROOT/resources/views/settings/imap/edit.blade.php" <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="container" style="max-width:720px">
  <h1 class="mb-3">IMAP Settings</h1>
  <p>Placeholder—form later.</p>
  <a href="{{ route('settings.index') }}">← Back</a>
</div>
@endsection
BLADE

[ -f "$ROOT/resources/views/settings/users/index.blade.php" ] || cat > "$ROOT/resources/views/settings/users/index.blade.php" <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="container" style="max-width:1024px">
  <div style="display:flex;justify-content:space-between;align-items:center;gap:16px">
    <h1 class="mb-3">Users</h1>
    <a href="{{ route('settings.index') }}">← Back</a>
  </div>
  <div style="overflow:auto;border:1px solid #e5e7eb;border-radius:12px">
    <table style="width:100%;border-collapse:collapse">
      <thead style="background:#f9fafb">
        <tr>
          <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e7eb">ID</th>
          <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e7eb">Name</th>
          <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e7eb">Email</th>
          <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e7eb">Created</th>
        </tr>
      </thead>
      <tbody>
        @foreach($users as $u)
          <tr>
            <td style="padding:10px;border-bottom:1px solid #f3f4f6">{{ $u->id }}</td>
            <td style="padding:10px;border-bottom:1px solid #f3f4f6">{{ $u->name }}</td>
            <td style="padding:10px;border-bottom:1px solid #f3f4f6">{{ $u->email }}</td>
            <td style="padding:10px;border-bottom:1px solid #f3f4f6">{{ $u->created_at?->format('Y-m-d') }}</td>
          </tr>
        @endforeach
      </tbody>
    </table>
  </div>
  <div class="mt-3">{{ $users->links() }}</div>
</div>
@endsection
BLADE

# --- Repair routes/web.php atomically (backup + replace clean file) ---
cp routes/web.php "routes/web.php.bak.$ts" 2>/dev/null || true
cat > routes/web.php <<'PHP'
<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\UserManagementController;
use App\Http\Controllers\ImapSettingsController;
use App\Http\Controllers\DropDownController;

Route::get('/', function () {
    return view('welcome');
});

// Authenticated area
Route::middleware(['auth'])->group(function () {
    // Dashboard (keep for safety)
    Route::get('/dashboard', function () { return view('dashboard'); })->name('dashboard');

    // Settings hub + subpages
    Route::get('/settings', [SettingsController::class, 'index'])->name('settings.index');
    Route::get('/settings/dropdowns', [DropDownController::class, 'index'])->name('settings.dropdowns.index');
    Route::get('/settings/imap', [ImapSettingsController::class, 'edit'])->name('settings.imap.edit');
    Route::get('/settings/users', [UserManagementController::class, 'index'])->name('settings.users.index');

    // Profile management if controller exists
    if (class_exists(ProfileController::class)) {
        Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
        Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
        Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
    }
});

if (file_exists(__DIR__.'/auth.php')) {
    require __DIR__.'/auth.php';
}
PHP

# --- Fix perms & caches inside container ---
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  DC=""
fi

if [ -n "$DC" ]; then
  $DC exec -T app sh -lc '
    set -e
    mkdir -p storage/framework/{views,cache,sessions} storage/logs bootstrap/cache
    chown -R www-data:www-data storage bootstrap/cache || true
    chmod -R 0777 storage bootstrap/cache
    rm -f storage/framework/views/* || true
    php -l routes/web.php || true
  '
  $DC exec -T -w /var/www/html app php artisan optimize:clear || true
  $DC exec -T -w /var/www/html app php artisan route:list | grep -E "settings\." || true
fi

echo "==> Routes fixed. Open /dashboard and /settings (logged in)."
