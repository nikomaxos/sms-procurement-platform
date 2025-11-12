#!/usr/bin/env bash
set -Eeuo pipefail

root="$(pwd)"

php_controller() {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$path")"
  if [ ! -f "$path" ] || ! diff -q <(echo "$content") "$path" >/dev/null 2>&1; then
    echo "$content" > "$path"
    echo "Wrote $path"
  else
    echo "OK (unchanged): $path"
  fi
}

blade_view() {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$path")"
  if [ ! -f "$path" ] || ! diff -q <(echo "$content") "$path" >/dev/null 2>&1; then
    echo "$content" > "$path"
    echo "Wrote $path"
  else
    echo "OK (unchanged): $path"
  fi
}

append_routes_once() {
  local marker="// <= SETTINGS MENU ROUTES"
  local block="$1"
  local web="$root/routes/web.php"
  grep -qF "$marker" "$web" 2>/dev/null && { echo "Routes already present."; return; }
  printf "\n%s\n%s\n" "$marker" "$block" >> "$web"
  echo "Appended settings routes to routes/web.php"
}

# 1) Controllers
php_controller "$root/app/Http/Controllers/SettingsController.php" "$(cat <<'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class SettingsController extends Controller {
    public function __construct() { $this->middleware('auth'); }

    public function index() {
        return view('settings.index');
    }
}
PHP
)"

php_controller "$root/app/Http/Controllers/UserManagementController.php" "$(cat <<'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;

class UserManagementController extends Controller {
    public function __construct() { $this->middleware('auth'); }

    public function index() {
        $users = User::query()->select(['id','name','email','created_at'])->orderBy('id')->paginate(20);
        return view('settings.users.index', compact('users'));
    }
}
PHP
)"

# 2) Views
blade_view "$root/resources/views/settings/index.blade.php" "$(cat <<'BLADE'
@extends('layouts.app')

@section('content')
<div class="container" style="max-width: 960px;">
  <h1 class="mb-4">Settings</h1>

  <div class="grid" style="display:grid;grid-template-columns: repeat(auto-fit,minmax(240px,1fr));gap:16px;">
    <a href="{{ route('settings.dropdowns.index') }}" class="card" style="display:block;text-decoration:none;border:1px solid #e5e7eb;border-radius:12px;padding:16px;">
      <h2 style="margin:0 0 8px 0;font-size:1.1rem;">Drop Down Menus</h2>
      <p style="margin:0;color:#6b7280;">Manage selectable lists used across the app.</p>
    </a>

    <a href="{{ route('settings.imap.edit') }}" class="card" style="display:block;text-decoration:none;border:1px solid #e5e7eb;border-radius:12px;padding:16px;">
      <h2 style="margin:0 0 8px 0;font-size:1.1rem;">IMAP Settings</h2>
      <p style="margin:0;color:#6b7280;">Configure mailbox and polling (minutes) for email intake.</p>
    </a>

    <a href="{{ route('settings.users.index') }}" class="card" style="display:block;text-decoration:none;border:1px solid #e5e7eb;border-radius:12px;padding:16px;">
      <h2 style="margin:0 0 8px 0;font-size:1.1rem;">Users Management</h2>
      <p style="margin:0;color:#6b7280;">View users; (extend later for roles, invites, etc.).</p>
    </a>
  </div>
</div>
@endsection
BLADE
)"

blade_view "$root/resources/views/settings/users/index.blade.php" "$(cat <<'BLADE'
@extends('layouts.app')

@section('content')
<div class="container" style="max-width: 1024px;">
  <div style="display:flex;align-items:center;justify-content:space-between;gap:16px;">
    <h1 class="mb-3">Users</h1>
    <a href="{{ route('settings.index') }}" style="text-decoration:none;">← Back to Settings</a>
  </div>

  <div style="overflow:auto;border:1px solid #e5e7eb;border-radius:12px;">
    <table style="width:100%;border-collapse:collapse;">
      <thead style="background:#f9fafb;">
        <tr>
          <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e7eb;">ID</th>
          <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e7eb;">Name</th>
          <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e7eb;">Email</th>
          <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e7eb;">Created</th>
        </tr>
      </thead>
      <tbody>
        @foreach ($users as $u)
          <tr>
            <td style="padding:10px;border-bottom:1px solid #f3f4f6;">{{ $u->id }}</td>
            <td style="padding:10px;border-bottom:1px solid #f3f4f6;">{{ $u->name }}</td>
            <td style="padding:10px;border-bottom:1px solid #f3f4f6;">{{ $u->email }}</td>
            <td style="padding:10px;border-bottom:1px solid #f3f4f6;">{{ $u->created_at?->format('Y-m-d') }}</td>
          </tr>
        @endforeach
      </tbody>
    </table>
  </div>

  <div class="mt-3">
    {{ $users->links() }}
  </div>
</div>
@endsection
BLADE
)"

# 3) Routes
append_routes_once "$(cat <<'ROUTES'
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\UserManagementController;
// [Inference] If these exist in your app already, these 'use' lines are harmless.
use App\Http\Controllers\ImapSettingsController;
use App\Http\Controllers\DropDownController;

Route::middleware(['auth'])->group(function () {
    Route::get('/settings', [SettingsController::class, 'index'])->name('settings.index');

    // Subpages (ensure controllers exist or add stubs later)
    Route::get('/settings/dropdowns', [DropDownController::class, 'index'])->name('settings.dropdowns.index');
    Route::get('/settings/imap', [ImapSettingsController::class, 'edit'])->name('settings.imap.edit');
    Route::get('/settings/users', [UserManagementController::class, 'index'])->name('settings.users.index');
});
ROUTES
)"

# 4) Permissions & cache
chmod -R a+rX "$root/resources" || true
chmod -R a+rX "$root/app/Http/Controllers" || true

# 5) Rebuild routes/views cache inside container
if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    dc="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    dc="docker-compose"
  else
    dc=""
  fi

  if [ -n "$dc" ]; then
    $dc exec -T -w /var/www/html app php artisan optimize:clear || true
    $dc exec -T -w /var/www/html app php artisan route:cache || true
    $dc exec -T -w /var/www/html app php artisan view:cache || true
  fi
fi

echo "==> Settings hub added. Visit /settings (must be logged in)."
