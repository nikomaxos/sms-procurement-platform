#!/usr/bin/env bash
set -Eeuo pipefail
run(){ if docker compose ps app >/dev/null 2>&1; then docker compose exec -T app bash -lc "$*"; else bash -lc "$*"; fi; }
[[ -f artisan ]] || { echo "[x] Run from Laravel project root"; exit 1; }

echo "[1/7] Listeners for login/logout -> auth_logs"
mkdir -p app/Listeners
cat > app/Listeners/LogSuccessfulLogin.php <<'PHP'
<?php
namespace App\Listeners;
use Illuminate\Auth\Events\Login;
use App\Models\AuthLog;
class LogSuccessfulLogin {
    public function handle(Login $event): void {
        AuthLog::create([
            'user_id'    => $event->user->id ?? null,
            'event'      => 'login',
            'ip'         => request()?->ip(),
            'user_agent' => request()?->userAgent(),
        ]);
    }
}
PHP
cat > app/Listeners/LogSuccessfulLogout.php <<'PHP'
<?php
namespace App\Listeners;
use Illuminate\Auth\Events\Logout;
use App\Models\AuthLog;
class LogSuccessfulLogout {
    public function handle(Logout $event): void {
        AuthLog::create([
            'user_id'    => $event->user->id ?? null,
            'event'      => 'logout',
            'ip'         => request()?->ip(),
            'user_agent' => request()?->userAgent(),
        ]);
    }
}
PHP

echo "[2/7] Wire listeners in EventServiceProvider"
cat > app/Providers/EventServiceProvider.php <<'PHP'
<?php
namespace App\Providers;
use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\Logout;
use App\Listeners\LogSuccessfulLogin;
use App\Listeners\LogSuccessfulLogout;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;
class EventServiceProvider extends ServiceProvider
{
    protected $listen = [
        Login::class  => [LogSuccessfulLogin::class],
        Logout::class => [LogSuccessfulLogout::class],
    ];
    public function boot(): void { parent::boot(); }
}
PHP

echo "[3/7] Make user creation lenient (password optional; observer will hash)"
mkdir -p app/Http/Controllers/Settings
cat > app/Http/Controllers/Settings/UserController.php <<'PHP'
<?php
namespace App\Http\Controllers\Settings;
use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function index() {
        $users = User::orderBy('id','desc')->paginate(20);
        return view('settings.users.index', compact('users'));
    }
    public function create() { return view('settings.users.create'); }
    public function store() {
        $data = request()->validate([
            'name'     => ['required','string','max:255'],
            'email'    => ['required','email','max:255', Rule::unique('users','email')],
            'password' => ['nullable','string','min:8'],
            'is_admin' => ['nullable','boolean'],
        ]);
        $data['is_admin'] = (bool)($data['is_admin'] ?? false);
        User::create($data); // UserObserver hashes / defaults password
        return redirect()->route('settings.users.index')->with('status','User created');
    }
    public function edit(User $user) { return view('settings.users.edit', compact('user')); }
    public function update(User $user) {
        $data = request()->validate([
            'name'     => ['required','string','max:255'],
            'email'    => ['required','email','max:255', Rule::unique('users','email')->ignore($user->id)],
            'password' => ['nullable','string','min:8'],
            'is_admin' => ['nullable','boolean'],
        ]);
        if(empty($data['password'])) unset($data['password']);
        $data['is_admin'] = (bool)($data['is_admin'] ?? false);
        $user->update($data);
        return redirect()->route('settings.users.index')->with('status','User updated');
    }
    public function destroy(User $user) {
        $user->delete();
        return back()->with('status','User deleted');
    }
}
PHP

# Minimal views (only if missing) to avoid 404s while keeping your current ones if they exist
mkdir -p resources/views/settings/users
for v in index create edit; do
  if [ ! -f "resources/views/settings/users/$v.blade.php" ]; then
    cat > "resources/views/settings/users/$v.blade.php" <<'BLADE'
<x-app-layout>
<x-slot name="header"><h2 class="section-title">{{ __('Users') }}</h2></x-slot>
<div class="card">
    @if(session('status')) <div class="mb-3 text-green-700">{{ session('status') }}</div> @endif
    @isset($users)
      <div class="mb-4 flex justify-between items-center">
        <div class="section-subtitle">{{ __('Manage application users') }}</div>
        <a href="{{ route('settings.users.create') }}" class="btn-primary">{{ __('Add user') }}</a>
      </div>
      <table class="min-w-full text-sm">
        <thead><tr><th class="py-2 pe-4">ID</th><th class="py-2 pe-4">{{ __('Name') }}</th><th class="py-2 pe-4">{{ __('Email') }}</th><th class="py-2 pe-4">{{ __('Admin') }}</th><th></th></tr></thead>
        <tbody class="divide-y divide-gray-200">
          @foreach($users as $u)
          <tr>
            <td class="py-2 pe-4">{{ $u->id }}</td>
            <td class="py-2 pe-4">{{ $u->name }}</td>
            <td class="py-2 pe-4">{{ $u->email }}</td>
            <td class="py-2 pe-4">{{ $u->is_admin ? 'Yes' : 'No' }}</td>
            <td class="py-2 pe-4">
              <a class="btn" href="{{ route('settings.users.edit',$u) }}">{{ __('Edit') }}</a>
              <form method="POST" action="{{ route('settings.users.destroy',$u) }}" class="inline" onsubmit="return confirm('Delete?')">@csrf @method('DELETE')
                <button class="btn">{{ __('Delete') }}</button>
              </form>
            </td>
          </tr>
          @endforeach
        </tbody>
      </table>
      <div class="mt-4">{{ $users->links() }}</div>
    @endisset

    @isset($user)
    <form method="POST" action="{{ route('settings.users.update',$user) }}" class="grid gap-3 max-w-xl">@csrf @method('PUT')
      <x-input-label value="{{ __('Name') }}" />
      <input class="input" name="name" value="{{ old('name',$user->name) }}">
      <x-input-label value="{{ __('Email') }}" />
      <input class="input" name="email" value="{{ old('email',$user->email) }}">
      <x-input-label value="{{ __('Password (leave blank to keep)') }}" />
      <input class="input" name="password" type="password">
      <label class="inline-flex items-center gap-2 mt-2"><input type="checkbox" name="is_admin" value="1" @checked(old('is_admin',$user->is_admin))> {{ __('Admin') }}</label>
      <div class="mt-3"><button class="btn-primary">{{ __('Save') }}</button></div>
    </form>
    @else
    @if(request()->routeIs('settings.users.create'))
    <form method="POST" action="{{ route('settings.users.store') }}" class="grid gap-3 max-w-xl">@csrf
      <x-input-label value="{{ __('Name') }}" />
      <input class="input" name="name" value="{{ old('name') }}">
      <x-input-label value="{{ __('Email') }}" />
      <input class="input" name="email" value="{{ old('email') }}">
      <x-input-label value="{{ __('Password (optional)') }}" />
      <input class="input" name="password" type="password">
      <label class="inline-flex items-center gap-2 mt-2"><input type="checkbox" name="is_admin" value="1"> {{ __('Admin') }}</label>
      <div class="mt-3"><button class="btn-primary">{{ __('Create') }}</button></div>
    </form>
    @endif
    @endisset
</div>
</x-app-layout>
BLADE
  fi
done

echo "[4/7] Nicer Settings index (breadcrumb + tabs)"
mkdir -p resources/views/settings
cat > resources/views/settings/index.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="section-title">{{ __('Settings') }}</h2>
        <p class="section-subtitle">{{ __('Administration & configuration') }}</p>
    </x-slot>

    <nav class="breadcrumb mb-4 text-sm text-gray-500">
        <span class="text-gray-700">{{ __('Settings') }}</span>
    </nav>

    <div class="tabs mb-6 flex gap-2">
        <a href="{{ route('settings.users.index') }}" class="{{ request()->routeIs('settings.users.*') ? 'tab-active' : 'tab' }}">{{ __('Users') }}</a>
        <a href="{{ route('settings.dropdowns.index') }}" class="{{ request()->routeIs('settings.dropdowns.*') ? 'tab-active' : 'tab' }}">{{ __('Drop-down menus') }}</a>
        <a href="{{ route('settings.logs.index') }}" class="{{ request()->routeIs('settings.logs.*') ? 'tab-active' : 'tab' }}">{{ __('Auth Logs') }}</a>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <a href="{{ route('settings.users.index') }}" class="card hover:shadow transition">
            <h3 class="text-lg font-semibold">{{ __('User Management') }}</h3>
            <p class="text-gray-500 mt-1">{{ __('Create, edit and remove users; grant admin.') }}</p>
        </a>
        <a href="{{ route('settings.dropdowns.index') }}" class="card hover:shadow transition">
            <h3 class="text-lg font-semibold">{{ __('Drop-down menus') }}</h3>
            <p class="text-gray-500 mt-1">{{ __('Route Type, Known Hops, Charge Model') }}</p>
        </a>
        <a href="{{ route('settings.logs.index') }}" class="card hover:shadow transition">
            <h3 class="text-lg font-semibold">{{ __('Authentication Logs') }}</h3>
            <p class="text-gray-500 mt-1">{{ __('Recent sign-ins and sign-outs') }}</p>
        </a>
    </div>
</x-app-layout>
BLADE

echo "[5/7] Make dropdowns look like a subcategory (breadcrumb + tabs)"
mkdir -p resources/views/settings/dropdowns
cat > resources/views/settings/dropdowns/index.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="section-title">{{ __('Settings') }}</h2>
        <p class="section-subtitle">{{ __('Administration & configuration') }}</p>
    </x-slot>

    <nav class="breadcrumb mb-4 text-sm text-gray-500">
        <a href="{{ route('settings.index') }}" class="hover:underline">{{ __('Settings') }}</a>
        <span class="mx-2">›</span>
        <span class="text-gray-700">{{ __('Drop-down menus') }}</span>
    </nav>

    <div class="tabs mb-6 flex gap-2">
        <a href="{{ route('settings.users.index') }}" class="tab">{{ __('Users') }}</a>
        <a href="{{ route('settings.dropdowns.index') }}" class="tab-active">{{ __('Drop-down menus') }}</a>
        <a href="{{ route('settings.logs.index') }}" class="tab">{{ __('Auth Logs') }}</a>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {{-- Route Types --}}
        <div class="category">
            <h3>{{ __('Route Type') }}</h3>
            <p>{{ __('Direct, HQ, SS7, SIM, Local Bypass') }}</p>

            <form method="POST" action="{{ route('settings.route-types.store') }}" class="mb-4">
                @csrf
                <div class="flex gap-2">
                    <input name="name" type="text" class="input w-full" placeholder="{{ __('Add new type…') }}">
                    <button class="btn-primary">{{ __('Add') }}</button>
                </div>
            </form>

            <div class="overflow-x-auto">
                <table class="table">
                    <tbody class="divide-y divide-gray-200">
                        @foreach($routeTypes as $item)
                        <tr>
                            <td class="py-2 pe-2 w-full">{{ $item->name }}</td>
                            <td class="py-2 pe-2">
                                <form method="POST" action="{{ route('settings.route-types.update', $item) }}" class="flex gap-2">
                                    @csrf @method('PUT')
                                    <input name="name" value="{{ $item->name }}" class="input" />
                                    <button class="btn-primary">{{ __('Save') }}</button>
                                </form>
                            </td>
                            <td class="py-2">
                                <form method="POST" action="{{ route('settings.route-types.destroy', $item) }}" onsubmit="return confirm('Delete?')">
                                    @csrf @method('DELETE')
                                    <button class="btn">{{ __('Delete') }}</button>
                                </form>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>

        {{-- Known Hops --}}
        <div class="category">
            <h3>{{ __('Known Hops') }}</h3>
            <p>{{ __('0-Hop, 1-Hop, 2-Hops, N-Hops') }}</p>

            <form method="POST" action="{{ route('settings.known-hops.store') }}" class="mb-4">
                @csrf
                <div class="flex gap-2">
                    <input name="name" type="text" class="input w-full" placeholder="{{ __('Add new hop…') }}">
                    <button class="btn-primary">{{ __('Add') }}</button>
                </div>
            </form>

            <div class="overflow-x-auto">
                <table class="table">
                    <tbody class="divide-y divide-gray-200">
                        @foreach($knownHops as $item)
                        <tr>
                            <td class="py-2 pe-2 w-full">{{ $item->name }}</td>
                            <td class="py-2 pe-2">
                                <form method="POST" action="{{ route('settings.known-hops.update', $item) }}" class="flex gap-2">
                                    @csrf @method('PUT')
                                    <input name="name" value="{{ $item->name }}" class="input" />
                                    <button class="btn-primary">{{ __('Save') }}</button>
                                </form>
                            </td>
                            <td class="py-2">
                                <form method="POST" action="{{ route('settings.known-hops.destroy', $item) }}" onsubmit="return confirm('Delete?')">
                                    @csrf @method('DELETE')
                                    <button class="btn">{{ __('Delete') }}</button>
                                </form>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>

        {{-- Charge Models --}}
        <div class="category">
            <h3>{{ __('Charge Model') }}</h3>
            <p>{{ __('Per Submit, Per Delivered') }}</p>

            <form method="POST" action="{{ route('settings.charge-models.store') }}" class="mb-4">
                @csrf
                <div class="flex gap-2">
                    <input name="name" type="text" class="input w-full" placeholder="{{ __('Add new model…') }}">
                    <button class="btn-primary">{{ __('Add') }}</button>
                </div>
            </form>

            <div class="overflow-x-auto">
                <table class="table">
                    <tbody class="divide-y divide-gray-200">
                        @foreach($chargeModels as $item)
                        <tr>
                            <td class="py-2 pe-2 w-full">{{ $item->name }}</td>
                            <td class="py-2 pe-2">
                                <form method="POST" action="{{ route('settings.charge-models.update', $item) }}" class="flex gap-2">
                                    @csrf @method('PUT')
                                    <input name="name" value="{{ $item->name }}" class="input" />
                                    <button class="btn-primary">{{ __('Save') }}</button>
                                </form>
                            </td>
                            <td class="py-2">
                                <form method="POST" action="{{ route('settings.charge-models.destroy', $item) }}" onsubmit="return confirm('Delete?')">
                                    @csrf @method('DELETE')
                                    <button class="btn">{{ __('Delete') }}</button>
                                </form>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</x-app-layout>
BLADE

echo "[6/7] Extra Tailwind helpers (tabs/breadcrumb; spacing/contrast already set)"
css="resources/css/app.css"
mkdir -p "$(dirname "$css")"
if ! grep -q "/* === UI polish (readability, spacing) === */" "$css" 2>/dev/null; then
cat >> "$css" <<'CSS'
/* === UI polish (readability, spacing) === */
@layer base { body { @apply bg-gray-50 text-gray-900; } a { @apply text-blue-700 hover:text-blue-900; } }
@layer components {
  .card { @apply bg-white border border-gray-200 rounded-2xl shadow-sm p-6; }
  .section-title { @apply text-xl font-semibold text-gray-900; }
  .section-subtitle { @apply text-sm text-gray-500; }
  .category { @apply card mb-6; }
  .category h3 { @apply text-lg font-semibold text-gray-800 mb-1; }
  .category p { @apply text-sm text-gray-500 mb-4; }
  .table { @apply min-w-full text-sm; }
  .btn { @apply inline-flex items-center px-3 py-2 rounded-md font-medium border border-gray-300 bg-white text-gray-700 hover:bg-gray-50; }
  .btn-primary { @apply inline-flex items-center px-3 py-2 rounded-md font-semibold bg-blue-600 text-white hover:bg-blue-700; }
  .input { @apply rounded-md border-gray-300 focus:border-blue-500 focus:ring-blue-500; }
  .tabs .tab { @apply inline-flex items-center px-3 py-1.5 rounded-full border border-gray-300 bg-white text-gray-700 hover:bg-gray-50; }
  .tabs .tab-active { @apply inline-flex items-center px-3 py-1.5 rounded-full border border-blue-600 bg-blue-600 text-white; }
  .breadcrumb { @apply text-sm text-gray-500; }
}
CSS
fi

echo "[7/7] Migrate, rebuild assets, clear caches"
run "php artisan migrate --force || true"
if docker compose ps node >/dev/null 2>&1; then docker compose run --rm node 'npm ci && npm run build'; else npm ci && npm run build; fi
run "php artisan config:clear && php artisan route:clear && php artisan view:clear"
docker compose restart app web >/dev/null || true
echo "[✓] Done. Visit /settings, /settings/dropdowns, /settings/logs. Then log out/in to populate logs."
