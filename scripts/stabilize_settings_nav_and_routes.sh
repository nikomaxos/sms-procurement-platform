#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(pwd)"

# --- 1) Base Controller (gives ->middleware()) ---
install_base_controller() {
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
  echo "Wrote: app/Http/Controllers/Controller.php"
}

# --- 2) Settings controllers (auth protected) ---
install_controllers() {
  cat > "$ROOT/app/Http/Controllers/SettingsController.php" <<'PHP'
<?php
namespace App\Http\Controllers;

class SettingsController extends Controller {
    public function __construct(){ $this->middleware('auth'); }
    public function index(){ return view('settings.index'); }
}
PHP
  echo "Wrote: app/Http/Controllers/SettingsController.php"

  cat > "$ROOT/app/Http/Controllers/DropDownController.php" <<'PHP'
<?php
namespace App\Http\Controllers;

class DropDownController extends Controller {
    public function __construct(){ $this->middleware('auth'); }
    public function index(){ return view('settings.dropdowns.index'); }
}
PHP
  echo "Wrote: app/Http/Controllers/DropDownController.php"

  cat > "$ROOT/app/Http/Controllers/ImapSettingsController.php" <<'PHP'
<?php
namespace App\Http\Controllers;

class ImapSettingsController extends Controller {
    public function __construct(){ $this->middleware('auth'); }
    public function edit(){ return view('settings.imap.edit'); }
}
PHP
  echo "Wrote: app/Http/Controllers/ImapSettingsController.php"

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
  echo "Wrote: app/Http/Controllers/UserManagementController.php"
}

# --- 3) Views (CSP-safe, no JS) ---
install_views() {
  mkdir -p "$ROOT/resources/views/settings/dropdowns" \
           "$ROOT/resources/views/settings/imap" \
           "$ROOT/resources/views/settings/users" \
           "$ROOT/resources/views/partials"

  cat > "$ROOT/resources/views/settings/index.blade.php" <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="container" style="max-width:960px">
  <h1 class="mb-4">Settings</h1>
  <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px">
    <a href="{{ route('settings.dropdowns.index') }}" style="display:block;border:1px solid #e5e7eb;border-radius:12px;padding:16px;text-decoration:none">
      <h2 style="margin:0 0 8px 0;font-size:1.1rem">Drop Down Menus</h2>
      <p style="margin:0;color:#6b7280">Manage selectable lists (stub).</p>
    </a>
    <a href="{{ route('settings.imap.edit') }}" style="display:block;border:1px solid #e5e7eb;border-radius:12px;padding:16px;text-decoration:none">
      <h2 style="margin:0 0 8px 0;font-size:1.1rem">IMAP Settings</h2>
      <p style="margin:0;color:#6b7280">Configure mailbox & polling (stub).</p>
    </a>
    <a href="{{ route('settings.users.index') }}" style="display:block;border:1px solid #e5e7eb;border-radius:12px;padding:16px;text-decoration:none">
      <h2 style="margin:0 0 8px 0;font-size:1.1rem">Users Management</h2>
      <p style="margin:0;color:#6b7280">View users (basic list).</p>
    </a>
  </div>
</div>
@endsection
BLADE
  echo "Wrote: resources/views/settings/index.blade.php"

  cat > "$ROOT/resources/views/settings/dropdowns/index.blade.php" <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="container" style="max-width:960px">
  <h1 class="mb-3">Drop Down Menus</h1>
  <p>Placeholder—wire CRUD later.</p>
  <a href="{{ route('settings.index') }}">← Back to Settings</a>
</div>
@endsection
BLADE
  echo "Wrote: resources/views/settings/dropdowns/index.blade.php"

  cat > "$ROOT/resources/views/settings/imap/edit.blade.php" <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="container" style="max-width:720px">
  <h1 class="mb-3">IMAP Settings</h1>
  <p>Placeholder—form & save logic later.</p>
  <a href="{{ route('settings.index') }}">← Back to Settings</a>
</div>
@endsection
BLADE
  echo "Wrote: resources/views/settings/imap/edit.blade.php"

  cat > "$ROOT/resources/views/settings/users/index.blade.php" <<'BLADE'
@extends('layouts.app')
@section('content')
<div class="container" style="max-width:1024px">
  <div style="display:flex;justify-content:space-between;align-items:center;gap:16px">
    <h1 class="mb-3">Users</h1>
    <a href="{{ route('settings.index') }}">← Back to Settings</a>
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
  echo "Wrote: resources/views/settings/users/index.blade.php"

  # Settings nav partial
  cat > "$ROOT/resources/views/partials/settings_nav.blade.php" <<'BLADE'
@auth
<nav style="background:#f9fafb;border-bottom:1px solid #e5e7eb;padding:10px 16px">
  <a href="{{ route('settings.index') }}" style="text-decoration:none;color:#111827">⚙️ Settings</a>
</nav>
@endauth
BLADE
  echo "Wrote: resources/views/partials/settings_nav.blade.php"
}

# --- 4) Routes (replace block between markers) ---
install_routes() {
  local WEB="$ROOT/routes/web.php"
  if ! grep -q '^<\?php' "$WEB" 2>/dev/null; then
    # ensure PHP context
    sed -i '1i <?php' "$WEB"
  fi
  # remove existing block
  sed -i '/=== SETTINGS ROUTES START ===/,/=== SETTINGS ROUTES END ===/d' "$WEB"
  # append fresh block
  cat >> "$WEB" <<'ROUTES'
// === SETTINGS ROUTES START ===
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\UserManagementController;
use App\Http\Controllers\ImapSettingsController;
use App\Http\Controllers\DropDownController;

Route::middleware(['auth'])->group(function () {
    Route::get('/settings', [SettingsController::class, 'index'])->name('settings.index');
    Route::get('/settings/dropdowns', [DropDownController::class, 'index'])->name('settings.dropdowns.index');
    Route::get('/settings/imap', [ImapSettingsController::class, 'edit'])->name('settings.imap.edit');
    Route::get('/settings/users', [UserManagementController::class, 'index'])->name('settings.users.index');
});
// === SETTINGS ROUTES END ===
ROUTES
  echo "Patched: routes/web.php (settings routes)"
}

# --- 5) Add Settings link into UI (Breeze + fallback) ---
install_nav_link() {
  local NAV="$ROOT/resources/views/layouts/navigation.blade.php"
  local LAY="$ROOT/resources/views/layouts/app.blade.php"

  # Breeze-style nav component file
  if [ -f "$NAV" ] && ! grep -q "settings.index" "$NAV"; then
    # append a Settings nav item at end of the primary link group
    cat >> "$NAV" <<'NAVX'

<!-- Settings link (added) -->
<x-nav-link :href="route('settings.index')" :active="request()->routeIs('settings.*')">
    {{ __('Settings') }}
</x-nav-link>
NAVX
    echo "Injected Settings link into layouts/navigation.blade.php"
  fi

  # Fallback: include a partial before @yield('content') or after <body>
  if [ -f "$LAY" ] && ! grep -q "partials.settings_nav" "$LAY"; then
    if grep -q "@yield('content')" "$LAY"; then
      sed -i "/@yield('content')/i @includeIf('partials.settings_nav')" "$LAY" || true
      echo "Inserted settings nav include in layouts/app.blade.php (before @yield('content'))"
    else
      sed -i '0,/<body[^>]*>/s//&\
@includeIf('\''partials.settings_nav'\'')/' "$LAY" || true
      echo "Inserted settings nav include in layouts/app.blade.php (after <body>)"
    fi
  fi
}

# --- 6) Fix perms inside container (permissive for dev) & rebuild caches ---
fix_perms_and_cache() {
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
      # try to give to www-data; then open perms permissively to avoid UID/GID mismatch issues
      chown -R www-data:www-data storage bootstrap/cache || true
      find storage bootstrap/cache -type d -exec chmod 0777 {} \;
      find storage bootstrap/cache -type f -exec chmod 0666 {} \;
      rm -f storage/framework/views/* || true
    '
    $DC exec -T -w /var/www/html app php artisan optimize:clear || true
    $DC exec -T -w /var/www/html app php artisan view:cache || true
    $DC exec -T -w /var/www/html app php artisan route:cache || true
    $DC exec -T -w /var/www/html app php artisan config:cache || true
  fi
}

install_base_controller
install_controllers
install_views
install_routes
install_nav_link
fix_perms_and_cache

echo "==> Done. Visit /settings (logged in) and its subpages."
