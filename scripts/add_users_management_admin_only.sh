#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

############################
# 1) Migration: users.role
############################
php_mig_dir="database/migrations"
mkdir -p "$php_mig_dir"
mig_file="$(date +%Y_%m_%d_%H%M%S)_add_role_to_users_table.php"
cat > "$php_mig_dir/$mig_file" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasColumn('users', 'role')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('role')->default('standard')->index();
            });
        }
    }
    public function down(): void {
        if (Schema::hasColumn('users', 'role')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('role');
            });
        }
    }
};
PHP

#############################################
# 2) Controller: admin-only Users management
#############################################
mkdir -p app/Http/Controllers/Settings
cat > app/Http/Controllers/Settings/UsersManagementController.php <<'PHP'
<?php

namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Illuminate\Support\Facades\Hash;

class UsersManagementController extends Controller
{
    public function __construct() {
        $this->middleware('auth');
        // Admin-only guard (no Gate/Provider edits needed)
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
        // prevent self delete
        if ($request->user()->id === $user->id) {
            return back()->withErrors(['delete' => "You can't delete your own account while logged in."]);
        }
        $user->delete();
        return redirect()->route('settings.users.index')->with('status', 'user-deleted');
    }
}
PHP

######################################
# 3) Routes under /settings/users
######################################
routes="routes/web.php"
if ! grep -q "settings.users.index" "$routes"; then
  cat >> "$routes" <<'PHP'

// Users Management (admin-only via controller middleware)
Route::middleware(['auth'])->prefix('settings')->name('settings.')->group(function () {
    Route::resource('users', \App\Http\Controllers\Settings\UsersManagementController::class)
         ->except(['show'])
         ->names('users');
});
PHP
fi

######################################
# 4) Views (index/create/edit)
######################################
mkdir -p resources/views/settings/users

# index
cat > resources/views/settings/users/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <div class="flex items-center justify-between">
      <h2 class="font-semibold text-xl text-gray-800 leading-tight">Users Management</h2>
      <a href="{{ route('settings.users.create') }}"
         class="inline-flex items-center rounded bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Add User</a>
    </div>
  </x-slot>

  @if (session('status') === 'user-created')
    <div class="mb-4 rounded border border-green-200 bg-green-50 text-green-800 px-4 py-2 text-sm">User created.</div>
  @elseif (session('status') === 'user-updated')
    <div class="mb-4 rounded border border-green-200 bg-green-50 text-green-800 px-4 py-2 text-sm">User updated.</div>
  @elseif (session('status') === 'user-deleted')
    <div class="mb-4 rounded border border-green-200 bg-green-50 text-green-800 px-4 py-2 text-sm">User deleted.</div>
  @endif
  @if ($errors->any())
    <div class="mb-4 rounded border border-red-200 bg-red-50 text-red-800 px-4 py-2 text-sm">
      {{ $errors->first() }}
    </div>
  @endif

  <div class="bg-white border rounded">
    <div class="overflow-x-auto">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50 text-gray-600">
          <tr>
            <th class="px-4 py-2 text-left">ID</th>
            <th class="px-4 py-2 text-left">Name</th>
            <th class="px-4 py-2 text-left">Email</th>
            <th class="px-4 py-2 text-left">Role</th>
            <th class="px-4 py-2 text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          @foreach ($users as $u)
            <tr class="border-t">
              <td class="px-4 py-2">{{ $u->id }}</td>
              <td class="px-4 py-2">{{ $u->name }}</td>
              <td class="px-4 py-2">{{ $u->email }}</td>
              <td class="px-4 py-2">{{ ucfirst($u->role) }}</td>
              <td class="px-4 py-2 text-right">
                <a href="{{ route('settings.users.edit', $u) }}"
                   class="text-indigo-600 hover:text-indigo-800 mr-3">Edit</a>
                <form action="{{ route('settings.users.destroy', $u) }}" method="POST" class="inline"
                      onsubmit="return confirm('Delete this user?');">
                  @csrf @method('DELETE')
                  <button class="text-red-600 hover:text-red-800">Delete</button>
                </form>
              </td>
            </tr>
          @endforeach
        </tbody>
      </table>
    </div>
    <div class="px-4 py-3 border-t">
      {{ $users->links() }}
    </div>
  </div>
</x-app-layout>
BLADE

# create
cat > resources/views/settings/users/create.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Add User</h2>
  </x-slot>

  <form method="POST" action="{{ route('settings.users.store') }}" class="max-w-2xl space-y-6">
    @csrf

    <div>
      <label class="block text-sm font-medium text-gray-700">Name</label>
      <input name="name" type="text" value="{{ old('name') }}" required
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
      @error('name')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">Email</label>
      <input name="email" type="email" value="{{ old('email') }}" required
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
      @error('email')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">Role</label>
      <select name="role" class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
        <option value="standard" {{ old('role','standard')==='standard'?'selected':'' }}>Standard</option>
        <option value="admin"    {{ old('role')==='admin'?'selected':'' }}>Admin</option>
      </select>
      @error('role')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">Password</label>
      <input name="password" type="password" required autocomplete="new-password"
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
      @error('password')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">Confirm Password</label>
      <input name="password_confirmation" type="password" required autocomplete="new-password"
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
    </div>

    <div class="flex items-center gap-3">
      <button class="inline-flex items-center rounded bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Create</button>
      <a href="{{ route('settings.users.index') }}" class="text-sm text-gray-600 hover:text-gray-900">Cancel</a>
    </div>
  </form>
</x-app-layout>
BLADE

# edit
cat > resources/views/settings/users/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit User</h2>
  </x-slot>

  <form method="POST" action="{{ route('settings.users.update', $user) }}" class="max-w-2xl space-y-6">
    @csrf @method('PUT')

    <div>
      <label class="block text-sm font-medium text-gray-700">Name</label>
      <input name="name" type="text" value="{{ old('name', $user->name) }}" required
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
      @error('name')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">Email</label>
      <input name="email" type="email" value="{{ old('email', $user->email) }}" required
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
      @error('email')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">Role</label>
      <select name="role" class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
        <option value="standard" {{ old('role', $user->role)==='standard'?'selected':'' }}>Standard</option>
        <option value="admin"    {{ old('role', $user->role)==='admin'?'selected':'' }}>Admin</option>
      </select>
      @error('role')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">New Password (optional)</label>
      <input name="password" type="password" autocomplete="new-password"
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
      @error('password')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">Confirm New Password</label>
      <input name="password_confirmation" type="password" autocomplete="new-password"
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
    </div>

    <div class="flex items-center gap-3">
      <button class="inline-flex items-center rounded bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Save</button>
      <a href="{{ route('settings.users.index') }}" class="text-sm text-gray-600 hover:text-gray-900">Cancel</a>
    </div>
  </form>
</x-app-layout>
BLADE

#########################################################
# 5) Sidebar link visible only for admins (hide for others)
#########################################################
side="resources/views/partials/sidebar.blade.php"
if [ -f "$side" ]; then
  # Replace the Users Management anchor block with an @if guard around it
  awk '
    BEGIN{inUsers=0}
    /Users Management/ {inUsers=1}
    {buf=buf $0 "\n"}
    END{
      gsub(/([[:space:]]*)<a href="{{ url\(''\/settings\/users''\) }}"[\s\S]*?Users Management[\s\S]*?<\/a>/,
           "@if(auth()->check() && auth()->user()->role === '\''admin'\'')\n\\1<a href=\"{{ url('\''/settings/users'\'') }}\" class=\"block rounded px-3 py-2 {{ request()->is('\''settings/users*'\'' ) ? '\''bg-gray-100 text-gray-900'\'' : '\''text-gray-700 hover:bg-gray-50'\'' }}\">Users Management</a>\n@endif", buf);
      print buf;
    }
  ' "$side" > "$side.tmp" && mv "$side.tmp" "$side" || true
fi

#############################################
# 6) Migrate & promote initial admin
#############################################
$DC exec -T app php artisan migrate --force

# Promote admin@example.com if exists; else promote user id=1
$DC exec -T app php -r '
require "vendor/autoload.php";
$app=require "bootstrap/app.php";
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use App\Models\User;
$u = User::where("email","admin@example.com")->first();
if(!$u){ $u = User::find(1); }
if($u){ $u->role="admin"; $u->save(); echo "Promoted user #{$u->id} ({$u->email}) to admin\n"; }
else { echo "No user found to promote; create one from UI.\n"; }
'

#############################################
# 7) Clear caches
#############################################
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan view:cache  || true
$DC exec -T app php artisan route:cache || true

echo "==> Users Management CRUD installed (admin-only). Visit /settings/users (as admin)."
