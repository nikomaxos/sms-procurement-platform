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

# 1) Ensure base Controller exists (gives ->middleware())
write_file "$ROOT/app/Http/Controllers/Controller.php" "<?php
namespace App\\Http\\Controllers;

use Illuminate\\Foundation\\Auth\\Access\\AuthorizesRequests;
use Illuminate\\Foundation\\Validation\\ValidatesRequests;
use Illuminate\\Routing\\Controller as BaseController;

class Controller extends BaseController
{
    use AuthorizesRequests, ValidatesRequests;
}
"

# 2) Make sure Settings controllers extend our base Controller
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

# 3) Minimal Settings views (if not present)
write_file "$ROOT/resources/views/settings/index.blade.php" "@extends('layouts.app')
@section('content')
<div class=\"container\" style=\"max-width:960px\">
  <h1 class=\"mb-4\">Settings</h1>
  <div style=\"display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px\">
    <a href=\"{{ route('settings.dropdowns.index') }}\" style=\"display:block;border:1px solid #e5e7eb;border-radius:12px;padding:16px;text-decoration:none\">
      <h2 style=\"margin:0 0 8px 0;font-size:1.1rem\">Drop Down Menus</h2>
      <p style=\"margin:0;color:#6b7280\">Manage selectable lists (stub).</p>
    </a>
    <a href=\"{{ route('settings.imap.edit') }}\" style=\"display:block;border:1px solid #e5e7eb;border-radius:12px;padding:16px;text-decoration:none\">
      <h2 style=\"margin:0 0 8px 0;font-size:1.1rem\">IMAP Settings</h2>
      <p style=\"margin:0;color:#6b7280\">Configure mailbox & polling (stub).</p>
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
  <p>Placeholder—wire CRUD later.</p>
  <a href=\"{{ route('settings.index') }}\">← Back to Settings</a>
</div>
@endsection
"

write_file "$ROOT/resources/views/settings/imap/edit.blade.php" "@extends('layouts.app')
@section('content')
<div class=\"container\" style=\"max-width:720px\">
  <h1 class=\"mb-3\">IMAP Settings</h1>
  <p>Placeholder—form & save logic later.</p>
  <a href=\"{{ route('settings.index') }}\">← Back to Settings</a>
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

# 4) Settings nav partial + inject into layout
write_file "$ROOT/resources/views/partials/settings_nav.blade.php" "@auth
<nav style=\"background:#f9fafb;border-bottom:1px solid #e5e7eb;padding:10px 16px\">
  <a href=\"{{ route('settings.index') }}\" style=\"text-decoration:none;color:#111827\">⚙️ Settings</a>
</nav>
@endauth
"

LAY="$ROOT/resources/views/layouts/app.blade.php"
if [ -f "$LAY" ] && ! grep -q \"settings.index\" \"$LAY\"; then
  # Try to insert above @yield('content')
  if grep -q \"@yield(['\\\"']content['\\\"'])\" \"$LAY\"; then
    sed -i \"/@yield(['\\\"']content['\\\"'])/i @includeIf('partials.settings_nav')\" \"$LAY\" || true
  elif grep -q \"@yield('content')\" \"$LAY\"; then
    sed -i \"/@yield('content')/i @includeIf('partials.settings_nav')\" \"$LAY\" || true
  else
    # Fallback: insert after <body>
    sed -i '0,/<body[^>]*>/s//&\n@includeIf('\\''partials.settings_nav'\\'')/' \"$LAY\" || true
  fi
  echo \"Inserted settings nav include in layouts/app.blade.php\"
else
  echo \"Layout not found or nav already present: skipping injection\"
fi

# 5) Fix storage perms and rebuild caches inside container
if docker compose version >/dev/null 2>&1; then
  DC=\"docker compose\"
elif command -v docker-compose >/dev/null 2>&1; then
  DC=\"docker-compose\"
else
  DC=\"\"
fi

if [ -n \"$DC\" ]; then
  $DC exec -T app sh -lc '
    set -e; umask 002
    mkdir -p storage/framework/{views,cache,sessions} storage/logs bootstrap/cache
    chown -R www-data:www-data storage bootstrap/cache
    find storage bootstrap/cache -type d -exec chmod 2775 {} \;
    find storage bootstrap/cache -type f -exec chmod 664 {} \;
    rm -f storage/framework/views/* || true
  '
  $DC exec -T -w /var/www/html app php artisan optimize:clear || true
  $DC exec -T -w /var/www/html app php artisan view:cache || true
  $DC exec -T -w /var/www/html app php artisan route:cache || true
  $DC exec -T -w /var/www/html app php artisan config:cache || true
fi

echo \"==> Done. Visit /settings and subpages; Settings link should appear globally.\"
