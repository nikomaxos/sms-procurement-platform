#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(pwd)"

write_file() {
  local path="$1"; shift
  local content="$*"
  mkdir -p "$(dirname "$path")"
  if [ ! -f "$path" ] || ! diff -q <(printf "%s" "$content") "$path" >/dev/null 2>&1; then
    printf "%s" "$content" > "$path"
    echo "Wrote: $path"
  else
    echo "OK (unchanged): $path"
  fi
}

# --- Controllers (auth-protected, minimal) ---
write_file "$ROOT/app/Http/Controllers/SettingsController.php" "<?php
namespace App\\Http\\Controllers;
class SettingsController extends Controller {
  public function __construct(){ \$this->middleware('auth'); }
  public function index(){ return view('settings.index'); }
}
"

write_file "$ROOT/app/Http/Controllers/DropDownController.php" "<?php
namespace App\\Http\\Controllers;
class DropDownController extends Controller {
  public function __construct(){ \$this->middleware('auth'); }
  public function index(){ return view('settings.dropdowns.index'); }
}
"

write_file "$ROOT/app/Http/Controllers/ImapSettingsController.php" "<?php
namespace App\\Http\\Controllers;
class ImapSettingsController extends Controller {
  public function __construct(){ \$this->middleware('auth'); }
  public function edit(){ return view('settings.imap.edit'); }
}
"

write_file "$ROOT/app/Http/Controllers/UserManagementController.php" "<?php
namespace App\\Http\\Controllers;
use App\\Models\\User;
class UserManagementController extends Controller {
  public function __construct(){ \$this->middleware('auth'); }
  public function index(){
    \$users = User::query()->select(['id','name','email','created_at'])->orderBy('id')->paginate(20);
    return view('settings.users.index', compact('users'));
  }
}
"

# --- Views (CSP-safe, no inline scripts) ---
write_file "$ROOT/resources/views/settings/index.blade.php" "@extends('layouts.app')
@section('content')
<div class=\"container\" style=\"max-width:960px\">
  <h1 class=\"mb-4\">Settings</h1>
  <div style=\"display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px\">
    <a href=\"{{ route('settings.dropdowns.index') }}\" style=\"display:block;border:1px solid #e5e7eb;border-radius:12px;padding:16px;text-decoration:none\">
      <h2 style=\"margin:0 0 8px 0;font-size:1.1rem\">Drop Down Menus</h2>
      <p style=\"margin:0;color:#6b7280\">Manage selectable lists (stub page).</p>
    </a>
    <a href=\"{{ route('settings.imap.edit') }}\" style=\"display:block;border:1px solid #e5e7eb;border-radius:12px;padding:16px;text-decoration:none\">
      <h2 style=\"margin:0 0 8px 0;font-size:1.1rem\">IMAP Settings</h2>
      <p style=\"margin:0;color:#6b7280\">Configure mailbox & polling (stub page).</p>
    </a>
    <a href=\"{{ route('settings.users.index') }}\" style=\"display:block;border:1px solid #e5e7eb;border-radius:12px;padding:16px;text-decoration:none\">
      <h2 style=\"margin:0 0 8px 0;font-size:1.1rem\">Users Management</h2>
      <p style=\"margin:0;color:#6b7280\">View users (basic list).</p>
    </a>
  </div>
</div>
@endsection
"

write_file "$ROOT/resources/views/settings/dropdowns/index.blade.php" "@extends('layouts.app')
@section('content')
<div class=\"container\" style=\"max-width:960px\">
  <h1 class=\"mb-3\">Drop Down Menus</h1>
  <p>This is a placeholder page. We’ll wire real CRUD later.</p>
  <a href=\"{{ route('settings.index') }}\">← Back to Settings</a>
</div>
@endsection
"

write_file "$ROOT/resources/views/settings/imap/edit.blade.php" "@extends('layouts.app')
@section('content')
<div class=\"container\" style=\"max-width:720px\">
  <h1 class=\"mb-3\">IMAP Settings</h1>
  <p>This is a placeholder page. Form and save logic will be added later.</p>
  <div style=\"display:grid;grid-template-columns:1fr 1fr;gap:12px\">
    <label>Host <input style=\"width:100%\" disabled placeholder=\"imap.example.com\"></label>
    <label>Port <input style=\"width:100%\" disabled placeholder=\"993\"></label>
    <label>Encryption <input style=\"width:100%\" disabled placeholder=\"ssl/tls\"></label>
    <label>Username <input style=\"width:100%\" disabled placeholder=\"user@example.com\"></label>
    <label>Poll minutes <input style=\"width:100%\" disabled placeholder=\"5\"></label>
    <label>Enabled <input type=\"checkbox\" disabled></label>
  </div>
  <div class=\"mt-3\"><a href=\"{{ route('settings.index') }}\">← Back to Settings</a></div>
</div>
@endsection
"

write_file "$ROOT/resources/views/settings/users/index.blade.php" "@extends('layouts.app')
@section('content')
<div class=\"container\" style=\"max-width:1024px\">
  <div style=\"display:flex;justify-content:space-between;align-items:center;gap:16px\">
    <h1 class=\"mb-3\">Users</h1>
    <a href=\"{{ route('settings.index') }}\">← Back to Settings</a>
  </div>
  <div style=\"overflow:auto;border:1px solid #e5e7eb;border-radius:12px\">
    <table style=\"width:100%;border-collapse:collapse\">
      <thead style=\"background:#f9fafb\">
        <tr>
          <th style=\"text-align:left;padding:10px;border-bottom:1px solid #e5e7eb\">ID</th>
          <th style=\"text-align:left;padding:10px;border-bottom:1px solid #e5e7eb\">Name</th>
          <th style=\"text-align:left;padding:10px;border-bottom:1px solid #e5e7eb\">Email</th>
          <th style=\"text-align:left;padding:10px;border-bottom:1px solid #e5e7eb\">Created</th>
        </tr>
      </thead>
      <tbody>
        @foreach($users as $u)
          <tr>
            <td style=\"padding:10px;border-bottom:1px solid #f3f4f6\">{{ $u->id }}</td>
            <td style=\"padding:10px;border-bottom:1px solid #f3f4f6\">{{ $u->name }}</td>
            <td style=\"padding:10px;border-bottom:1px solid #f3f4f6\">{{ $u->email }}</td>
            <td style=\"padding:10px;border-bottom:1px solid #f3f4f6\">{{ $u->created_at?->format('Y-m-d') }}</td>
          </tr>
        @endforeach
      </tbody>
    </table>
  </div>
  <div class=\"mt-3\">{{ $users->links() }}</div>
</div>
@endsection
"

# --- Routes (append once) ---
WEB="$ROOT/routes/web.php"
MARK="// <= SETTINGS MENU ROUTES"
if ! grep -qF "$MARK" "$WEB" 2>/dev/null; then
  cat >> "$WEB" <<'ROUTES'

<?php
// <= SETTINGS MENU ROUTES
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
ROUTES
  echo "Appended settings routes."
else
  echo "Routes already present."
fi

# --- Fix permissions INSIDE the container & rebuild caches ---
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
    rm -rf storage/framework/views/* || true
    chown -R www-data:www-data storage bootstrap/cache
    chmod -R 775 storage bootstrap/cache
  '
  $DC exec -T -w /var/www/html app php artisan optimize:clear || true
  $DC exec -T -w /var/www/html app php artisan view:cache || true
  $DC exec -T -w /var/www/html app php artisan route:cache || true
  $DC exec -T -w /var/www/html app php artisan config:cache || true
fi

echo "==> Ready. Open /settings (logged in)."
