#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

mkdir -p app/Http/Controllers/Auth resources/views/auth resources/views/partials

###############################################
# 1) Controller: PasswordChangeController
###############################################
cat > app/Http/Controllers/Auth/PasswordChangeController.php <<'PHP'
<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

class PasswordChangeController extends Controller
{
    public function edit(Request $request)
    {
        return view('auth.password-change');
    }

    public function update(Request $request)
    {
        $validated = $request->validate([
            'current_password' => ['required', 'current_password'],
            'password' => ['required', 'confirmed', Password::defaults()],
        ]);

        $user = $request->user();
        $user->forceFill([
            'password' => Hash::make($validated['password']),
        ])->save();

        // Refresh session to avoid any edge issues
        $request->session()->regenerate();

        return back()->with('status', 'password-changed');
    }
}
PHP

###############################################
# 2) Routes (auth-protected)
###############################################
ROUTES_FILE="routes/web.php"
if ! grep -q "password.change" "$ROUTES_FILE"; then
  cat >> "$ROUTES_FILE" <<'PHP'

// Change Password (auth)
Route::middleware('auth')->group(function () {
    Route::get('/password/change', [\App\Http\Controllers\Auth\PasswordChangeController::class, 'edit'])
        ->name('password.change');
    Route::put('/password/change', [\App\Http\Controllers\Auth\PasswordChangeController::class, 'update'])
        ->name('password.change.update');
});
PHP
fi

###############################################
# 3) View
###############################################
cat > resources/views/auth/password-change.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Change Password</h2>
  </x-slot>

  <div class="max-w-2xl">
    @if (session('status') === 'password-changed')
      <div class="mb-4 rounded border border-green-200 bg-green-50 text-green-800 px-4 py-2 text-sm">
        Password updated successfully.
      </div>
    @endif

    <form method="POST" action="{{ route('password.change.update') }}" class="space-y-6">
      @csrf
      @method('PUT')

      <div>
        <label for="current_password" class="block text-sm font-medium text-gray-700">Current password</label>
        <input id="current_password" name="current_password" type="password" required
               autocomplete="current-password"
               class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
        @error('current_password')
          <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
        @enderror
      </div>

      <div>
        <label for="password" class="block text-sm font-medium text-gray-700">New password</label>
        <input id="password" name="password" type="password" required
               autocomplete="new-password"
               class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
        @error('password')
          <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
        @enderror
      </div>

      <div>
        <label for="password_confirmation" class="block text-sm font-medium text-gray-700">Confirm new password</label>
        <input id="password_confirmation" name="password_confirmation" type="password" required
               autocomplete="new-password"
               class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
      </div>

      <div class="flex items-center gap-3">
        <button type="submit"
                class="inline-flex items-center rounded bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700 focus:outline-none">
          Update Password
        </button>
        <a href="{{ url()->previous() }}"
           class="text-sm text-gray-600 hover:text-gray-900">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

###############################################
# 4) Add link to the top-right user menu
###############################################
TOPBAR="resources/views/partials/topbar.blade.php"
if [ -f "$TOPBAR" ]; then
  # Overwrite with a small dropdown (hover) including Change Password
  cat > "$TOPBAR" <<'BLADE'
<header class="w-full border-b bg-white relative z-40">
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <div class="h-14 flex items-center justify-between">
      <a href="{{ url('/') }}" class="font-semibold text-gray-800">SMS Suppliers</a>

      <div class="flex items-center gap-4">
        @auth
          <div class="relative group">
            <button type="button" class="inline-flex items-center gap-2 text-sm text-gray-700 group-hover:text-gray-900">
              <span>{{ auth()->user()->name }}</span>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.17l3.71-3.94a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd"/></svg>
            </button>
            <div class="absolute right-0 mt-2 hidden group-hover:block bg-white border rounded-md shadow min-w-56 py-1">
              <a href="{{ route('password.change') }}" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50">Change Password</a>
              <form method="POST" action="{{ route('logout') }}">
                @csrf
                <button class="w-full text-left block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50">Logout</button>
              </form>
            </div>
          </div>
        @endauth

        @guest
          <a href="{{ route('login') }}" class="text-sm text-gray-700 hover:text-gray-900">Login</a>
        @endguest
      </div>
    </div>
  </div>
</header>
BLADE
fi

###############################################
# 5) Fix perms, clear caches, rebuild views
###############################################
$DC exec -T app bash -lc '
  mkdir -p storage/framework/{cache,sessions,views} bootstrap/cache storage/logs &&
  chown -R www-data:www-data storage bootstrap/cache &&
  chmod -R ug+rwX storage bootstrap/cache
'
$DC exec -T app php artisan view:clear
$DC exec -T app php artisan optimize

echo "==> Change-password feature installed. Open /password/change or use the user menu (top-right)."
