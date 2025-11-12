#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

echo "==> Rewriting UsersManagement controller and views"

mkdir -p app/Http/Controllers/Settings resources/views/settings/users

# --- Controller (admin-only via middleware) ---
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

# --- Views ---
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

# --- Routes: ensure single resource block present ---
routes="routes/web.php"
# Remove any half-written duplicates first
sed -i "/UsersManagementController/d" "$routes" || true
# Insert if missing
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

# --- Fix storage perms & clear caches ---
$DC exec -T app bash -lc '
  mkdir -p storage/framework/{cache,sessions,views} bootstrap/cache storage/logs &&
  chown -R www-data:www-data storage bootstrap/cache &&
  chmod -R ug+rwX storage bootstrap/cache
'
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan view:cache || true
$DC exec -T app php artisan route:cache || true

echo "==> Users Management repaired. Visit /settings/users as admin."
