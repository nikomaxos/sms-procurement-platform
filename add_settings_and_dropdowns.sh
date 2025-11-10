#!/usr/bin/env bash
set -euo pipefail

# Helper: run inside app container if Docker is up, else locally
run() {
  if docker compose ps app >/dev/null 2>&1; then
    docker compose exec -T app bash -lc "$*"
  else
    bash -lc "$*"
  fi
}

[[ -f artisan ]] || { echo "[x] Run from Laravel project root."; exit 1; }

# Ensure admin gate exists in AppServiceProvider
cat > app/Providers/AppServiceProvider.php <<'PHP'
<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\Gate;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        Gate::define('admin', fn($user) => (bool) $user->is_admin);
    }
}
PHP

# Models (taxonomies)
mkdir -p app/Models
cat > app/Models/RouteType.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;

class RouteType extends Model
{
    protected $fillable = ['name'];
}
PHP

cat > app/Models/KnownHop.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;

class KnownHop extends Model
{
    protected $fillable = ['name'];
}
PHP

cat > app/Models/ChargeModel.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;

class ChargeModel extends Model
{
    protected $fillable = ['name'];
}
PHP

# AuthLog model + migration + listeners
mkdir -p app/Models
cat > app/Models/AuthLog.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;

class AuthLog extends Model
{
    public $timestamps = false;
    protected $fillable = ['user_id','event','ip','user_agent','created_at'];
}
PHP

mkdir -p database/migrations
if ! ls database/migrations/*_create_auth_logs_table.php >/dev/null 2>&1; then
  TS=$(date +%Y_%m_%d_%H%M%S)
  cat > database/migrations/${TS}_create_auth_logs_table.php <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('auth_logs', function (Blueprint $t) {
            $t->id();
            $t->unsignedBigInteger('user_id')->nullable()->index();
            $t->string('event', 20); // login/logout
            $t->string('ip', 64)->nullable();
            $t->text('user_agent')->nullable();
            $t->timestamp('created_at')->useCurrent();
        });
    }
    public function down(): void {
        Schema::dropIfExists('auth_logs');
    }
};
PHP
fi

# Event listeners via EventServiceProvider
cat > app/Providers/EventServiceProvider.php <<'PHP'
<?php

namespace App\Providers;

use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\Logout;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\Event;
use App\Models\AuthLog;

class EventServiceProvider extends ServiceProvider
{
    protected $listen = [
        // (no concrete classes; we register closures in boot)
    ];

    public function boot(): void
    {
        Event::listen(Login::class, function ($event) {
            AuthLog::create([
                'user_id'    => optional($event->user)->id,
                'event'      => 'login',
                'ip'         => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);
        });

        Event::listen(Logout::class, function ($event) {
            AuthLog::create([
                'user_id'    => optional($event->user)->id,
                'event'      => 'logout',
                'ip'         => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);
        });
    }
}
PHP

# Controllers
mkdir -p app/Http/Controllers/Settings
cat > app/Http/Controllers/Settings/SettingsController.php <<'PHP'
<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;

class SettingsController extends Controller
{
    public function index()
    {
        return view('settings.index');
    }
}
PHP

cat > app/Http/Controllers/Settings/UserController.php <<'PHP'
<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function index() {
        $users = User::orderBy('id')->paginate(20);
        return view('settings.users.index', compact('users'));
    }

    public function create() {
        return view('settings.users.create');
    }

    public function store(Request $request) {
        $data = $request->validate([
            'name' => ['required','string','max:100'],
            'email' => ['required','email','max:150','unique:users,email'],
            'password' => ['required','string','min:8'],
            'is_admin' => ['nullable','boolean'],
        ]);
        $data['password'] = Hash::make($data['password']);
        $data['is_admin'] = (bool)($data['is_admin'] ?? false);
        User::create($data);
        return redirect()->route('settings.users.index')->with('status','User created.');
    }

    public function edit(User $user) {
        return view('settings.users.edit', compact('user'));
    }

    public function update(Request $request, User $user) {
        $data = $request->validate([
            'name' => ['required','string','max:100'],
            'email' => ['required','email','max:150', Rule::unique('users','email')->ignore($user->id)],
            'password' => ['nullable','string','min:8'],
            'is_admin' => ['nullable','boolean'],
        ]);
        if (!empty($data['password'])) {
            $data['password'] = Hash::make($data['password']);
        } else {
            unset($data['password']);
        }
        $data['is_admin'] = (bool)($data['is_admin'] ?? false);
        $user->update($data);
        return redirect()->route('settings.users.index')->with('status','User updated.');
    }

    public function destroy(User $user) {
        if (auth()->id() === $user->id) {
            return back()->with('status','You cannot delete yourself.');
        }
        $user->delete();
        return redirect()->route('settings.users.index')->with('status','User deleted.');
    }
}
PHP

for NAME in RouteType KnownHop ChargeModel; do
  lc=$(echo "$NAME" | sed 's/\(.\)\([A-Z]\)/\1_\L\2/g' | tr '[:upper:]' '[:lower:]')
  table="${lc}s"
  cat > "app/Http/Controllers/Settings/${NAME}Controller.php" <<PHP
<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\\$NAME;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ${NAME}Controller extends Controller
{
    public function index() {
        \$items = $NAME::orderBy('name')->get();
        return view('settings.dropdowns.index', [
            'routeTypes' => \\App\\Models\\RouteType::orderBy('name')->get(),
            'knownHops'  => \\App\\Models\\KnownHop::orderBy('name')->get(),
            'chargeModels'=> \\App\\Models\\ChargeModel::orderBy('name')->get(),
        ]);
    }

    public function store(Request \$request) {
        \$data = \$request->validate(['name' => ['required','string','max:100','unique:${table},name']]);
        $NAME::create(\$data);
        return back()->with('status','Saved.');
    }

    public function update(Request \$request, $NAME \$item) {
        \$data = \$request->validate(['name' => ['required','string','max:100', Rule::unique('${table}','name')->ignore(\$item->id)]]);
        \$item->update(\$data);
        return back()->with('status','Updated.');
    }

    public function destroy($NAME \$item) {
        \$item->delete();
        return back()->with('status','Deleted.');
    }
}
PHP
done

# Auth logs controller
cat > app/Http/Controllers/Settings/AuthLogController.php <<'PHP'
<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\AuthLog;

class AuthLogController extends Controller
{
    public function index()
    {
        $logs = AuthLog::orderByDesc('id')->paginate(50);
        return view('settings.logs.index', compact('logs'));
    }
}
PHP

# Routes
cat >> routes/web.php <<'PHP'

// === Settings (admin) ===
use App\Http\Controllers\Settings\SettingsController;
use App\Http\Controllers\Settings\UserController;
use App\Http\Controllers\Settings\RouteTypeController;
use App\Http\Controllers\Settings\KnownHopController;
use App\Http\Controllers\Settings\ChargeModelController;
use App\Http\Controllers\Settings\AuthLogController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::middleware('can:admin')->prefix('settings')->name('settings.')->group(function () {
        Route::get('/', [SettingsController::class, 'index'])->name('index');

        Route::resource('users', UserController::class)->except(['show']);

        // Dropdowns - single index page, resource actions per type
        Route::get('dropdowns', [RouteTypeController::class, 'index'])->name('dropdowns.index');
        Route::resource('route-types', RouteTypeController::class)->only(['store','update','destroy']);
        Route::resource('known-hops', KnownHopController::class)->only(['store','update','destroy']);
        Route::resource('charge-models', ChargeModelController::class)->only(['store','update','destroy']);

        Route::get('logs', [AuthLogController::class, 'index'])->name('logs.index');
    });
});
PHP

# Views
mkdir -p resources/views/settings users
cat > resources/views/settings/index.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl">Settings</h2>
    </x-slot>

    <div class="py-6">
        <div class="max-w-7xl mx-auto space-y-6">
            <div class="bg-white dark:bg-gray-800 shadow sm:rounded-lg p-6">
                <h3 class="text-lg font-medium mb-2">Administration</h3>
                <ul class="list-disc list-inside">
                    <li><a class="text-blue-600 underline" href="{{ route('settings.users.index') }}">Users</a></li>
                    <li><a class="text-blue-600 underline" href="{{ route('settings.dropdowns.index') }}">Drop-down Menus</a></li>
                    <li><a class="text-blue-600 underline" href="{{ route('settings.logs.index') }}">Auth Logs</a></li>
                </ul>
            </div>
        </div>
    </div>
</x-app-layout>
BLADE

mkdir -p resources/views/settings/users
cat > resources/views/settings/users/index.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between">
            <h2 class="font-semibold text-xl">Users</h2>
            <a href="{{ route('settings.users.create') }}" class="px-3 py-2 bg-blue-600 text-white rounded">New User</a>
        </div>
    </x-slot>

    <div class="p-6">
        @if (session('status')) <div class="mb-4 text-green-600">{{ session('status') }}</div> @endif
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead><tr class="text-left border-b">
                    <th class="py-2 pr-4">ID</th>
                    <th class="py-2 pr-4">Name</th>
                    <th class="py-2 pr-4">Email</th>
                    <th class="py-2 pr-4">Admin</th>
                    <th class="py-2 pr-4">Actions</th>
                </tr></thead>
                <tbody>
                @foreach($users as $u)
                    <tr class="border-b">
                        <td class="py-2 pr-4">{{ $u->id }}</td>
                        <td class="py-2 pr-4">{{ $u->name }}</td>
                        <td class="py-2 pr-4">{{ $u->email }}</td>
                        <td class="py-2 pr-4">{{ $u->is_admin ? 'Yes' : 'No' }}</td>
                        <td class="py-2 pr-4 space-x-2">
                            <a class="text-blue-600 underline" href="{{ route('settings.users.edit',$u) }}">Edit</a>
                            <form action="{{ route('settings.users.destroy',$u) }}" method="POST" class="inline" onsubmit="return confirm('Delete user?')">
                                @csrf @method('DELETE')
                                <button class="text-red-600 underline">Delete</button>
                            </form>
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
            <div class="mt-4">{{ $users->links() }}</div>
        </div>
    </div>
</x-app-layout>
BLADE

cat > resources/views/settings/users/create.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl">Create User</h2></x-slot>
    <div class="p-6">
        <form method="POST" action="{{ route('settings.users.store') }}" class="space-y-4 max-w-xl">
            @csrf
            <div>
                <label class="block">Name</label>
                <input name="name" class="w-full border rounded p-2" required>
                @error('name')<div class="text-red-600 text-sm">{{ $message }}</div>@enderror
            </div>
            <div>
                <label class="block">Email</label>
                <input type="email" name="email" class="w-full border rounded p-2" required>
                @error('email')<div class="text-red-600 text-sm">{{ $message }}</div>@enderror
            </div>
            <div>
                <label class="block">Password</label>
                <input type="password" name="password" class="w-full border rounded p-2" required>
                @error('password')<div class="text-red-600 text-sm">{{ $message }}</div>@enderror
            </div>
            <label class="inline-flex items-center space-x-2">
                <input type="checkbox" name="is_admin" value="1">
                <span>Admin</span>
            </label>
            <div class="pt-2">
                <button class="px-3 py-2 bg-blue-600 text-white rounded">Save</button>
                <a href="{{ route('settings.users.index') }}" class="ml-2 underline">Cancel</a>
            </div>
        </form>
    </div>
</x-app-layout>
BLADE

cat > resources/views/settings/users/edit.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl">Edit User #{{ $user->id }}</h2></x-slot>
    <div class="p-6">
        <form method="POST" action="{{ route('settings.users.update',$user) }}" class="space-y-4 max-w-xl">
            @csrf @method('PUT')
            <div>
                <label class="block">Name</label>
                <input name="name" class="w-full border rounded p-2" value="{{ old('name',$user->name) }}" required>
                @error('name')<div class="text-red-600 text-sm">{{ $message }}</div>@enderror
            </div>
            <div>
                <label class="block">Email</label>
                <input type="email" name="email" class="w-full border rounded p-2" value="{{ old('email',$user->email) }}" required>
                @error('email')<div class="text-red-600 text-sm">{{ $message }}</div>@enderror
            </div>
            <div>
                <label class="block">Password (leave empty to keep)</label>
                <input type="password" name="password" class="w-full border rounded p-2">
                @error('password')<div class="text-red-600 text-sm">{{ $message }}</div>@enderror
            </div>
            <label class="inline-flex items-center space-x-2">
                <input type="checkbox" name="is_admin" value="1" {{ $user->is_admin ? 'checked' : '' }}>
                <span>Admin</span>
            </label>
            <div class="pt-2">
                <button class="px-3 py-2 bg-blue-600 text-white rounded">Update</button>
                <a href="{{ route('settings.users.index') }}" class="ml-2 underline">Cancel</a>
            </div>
        </form>
    </div>
</x-app-layout>
BLADE

# Dropdowns combined page
mkdir -p resources/views/settings/dropdowns
cat > resources/views/settings/dropdowns/index.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl">Drop-down Menus</h2></x-slot>
    <div class="p-6 space-y-10">
        @if (session('status')) <div class="mb-4 text-green-600">{{ session('status') }}</div> @endif

        <section>
            <h3 class="text-lg font-semibold mb-2">Route Type</h3>
            <form method="POST" action="{{ route('settings.route-types.store') }}" class="mb-3 flex space-x-2">
                @csrf
                <input name="name" placeholder="e.g. Direct" class="border rounded p-2">
                <button class="px-3 py-2 bg-blue-600 text-white rounded">Add</button>
            </form>
            @error('name')<div class="text-red-600 text-sm mb-3">{{ $message }}</div>@enderror
            <table class="w-full text-sm">
                @foreach($routeTypes as $rt)
                <tr class="border-b">
                    <td class="py-2 pr-4 w-full">
                        <form method="POST" action="{{ route('settings.route-types.update',$rt) }}" class="flex space-x-2">
                            @csrf @method('PUT')
                            <input name="name" value="{{ $rt->name }}" class="border rounded p-2 w-full">
                            <button class="px-3 py-2 bg-green-600 text-white rounded">Save</button>
                        </form>
                    </td>
                    <td class="py-2">
                        <form method="POST" action="{{ route('settings.route-types.destroy',$rt) }}" onsubmit="return confirm('Delete?')">
                            @csrf @method('DELETE')
                            <button class="px-3 py-2 bg-red-600 text-white rounded">Delete</button>
                        </form>
                    </td>
                </tr>
                @endforeach
            </table>
        </section>

        <section>
            <h3 class="text-lg font-semibold mb-2">Known Hops</h3>
            <form method="POST" action="{{ route('settings.known-hops.store') }}" class="mb-3 flex space-x-2">
                @csrf
                <input name="name" placeholder="e.g. 1-Hop" class="border rounded p-2">
                <button class="px-3 py-2 bg-blue-600 text-white rounded">Add</button>
            </form>
            <table class="w-full text-sm">
                @foreach($knownHops as $kh)
                <tr class="border-b">
                    <td class="py-2 pr-4 w-full">
                        <form method="POST" action="{{ route('settings.known-hops.update',$kh) }}" class="flex space-x-2">
                            @csrf @method('PUT')
                            <input name="name" value="{{ $kh->name }}" class="border rounded p-2 w-full">
                            <button class="px-3 py-2 bg-green-600 text-white rounded">Save</button>
                        </form>
                    </td>
                    <td class="py-2">
                        <form method="POST" action="{{ route('settings.known-hops.destroy',$kh) }}" onsubmit="return confirm('Delete?')">
                            @csrf @method('DELETE')
                            <button class="px-3 py-2 bg-red-600 text-white rounded">Delete</button>
                        </form>
                    </td>
                </tr>
                @endforeach
            </table>
        </section>

        <section>
            <h3 class="text-lg font-semibold mb-2">Charge Model</h3>
            <form method="POST" action="{{ route('settings.charge-models.store') }}" class="mb-3 flex space-x-2">
                @csrf
                <input name="name" placeholder="e.g. Per Submit" class="border rounded p-2">
                <button class="px-3 py-2 bg-blue-600 text-white rounded">Add</button>
            </form>
            <table class="w-full text-sm">
                @foreach($chargeModels as $cm)
                <tr class="border-b">
                    <td class="py-2 pr-4 w-full">
                        <form method="POST" action="{{ route('settings.charge-models.update',$cm) }}" class="flex space-x-2">
                            @csrf @method('PUT')
                            <input name="name" value="{{ $cm->name }}" class="border rounded p-2 w-full">
                            <button class="px-3 py-2 bg-green-600 text-white rounded">Save</button>
                        </form>
                    </td>
                    <td class="py-2">
                        <form method="POST" action="{{ route('settings.charge-models.destroy',$cm) }}" onsubmit="return confirm('Delete?')">
                            @csrf @method('DELETE')
                            <button class="px-3 py-2 bg-red-600 text-white rounded">Delete</button>
                        </form>
                    </td>
                </tr>
                @endforeach
            </table>
        </section>
    </div>
</x-app-layout>
BLADE

# Auth logs
mkdir -p resources/views/settings/logs
cat > resources/views/settings/logs/index.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl">Auth Logs</h2></x-slot>
    <div class="p-6">
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead><tr class="text-left border-b">
                    <th class="py-2 pr-4">#</th>
                    <th class="py-2 pr-4">When</th>
                    <th class="py-2 pr-4">User</th>
                    <th class="py-2 pr-4">Event</th>
                    <th class="py-2 pr-4">IP</th>
                    <th class="py-2 pr-4">User Agent</th>
                </tr></thead>
                <tbody>
                @foreach($logs as $log)
                    <tr class="border-b">
                        <td class="py-2 pr-4">{{ $log->id }}</td>
                        <td class="py-2 pr-4">{{ $log->created_at }}</td>
                        <td class="py-2 pr-4">{{ $log->user_id }}</td>
                        <td class="py-2 pr-4">{{ $log->event }}</td>
                        <td class="py-2 pr-4">{{ $log->ip }}</td>
                        <td class="py-2 pr-4 truncate">{{ $log->user_agent }}</td>
                    </tr>
                @endforeach
                </tbody>
            </table>
            <div class="mt-4">{{ $logs->links() }}</div>
        </div>
    </div>
</x-app-layout>
BLADE

# Add Settings link to Breeze nav (non-destructive append if not present)
NAV="resources/views/layouts/navigation.blade.php"
if ! grep -q "route('settings.index')" "$NAV"; then
  cat >> "$NAV" <<'BLADE'

@can('admin')
    <x-nav-link :href="route('settings.index')" :active="request()->routeIs('settings.*')">
        {{ __('Settings') }}
    </x-nav-link>
@endcan
BLADE
fi

# Seed default taxonomy values (safe to re-run)
cat > database/seeders/DropdownSeeder.php <<'PHP'
<?php
namespace Database\Seeders;
use Illuminate\Database\Seeder;
use App\Models\RouteType;
use App\Models\KnownHop;
use App\Models\ChargeModel;

class DropdownSeeder extends Seeder
{
    public function run(): void
    {
        foreach (['Direct','HQ','SS7','SIM','Local Bypass'] as $v) {
            RouteType::firstOrCreate(['name'=>$v]);
        }
        foreach (['0-Hop','1-Hop','2-Hops','N-Hops'] as $v) {
            KnownHop::firstOrCreate(['name'=>$v]);
        }
        foreach (['Per Submit','Per Delivered'] as $v) {
            ChargeModel::firstOrCreate(['name'=>$v]);
        }
    }
}
PHP

# Make sure DatabaseSeeder calls DropdownSeeder (idempotent)
sed -i '/DropdownSeeder/d' database/seeders/DatabaseSeeder.php
awk '1;/run\(\): void \{/ && !x {print "        $this->call(\\Database\\Seeders\\DropdownSeeder::class);"; x=1}' database/seeders/DatabaseSeeder.php > /tmp/dbs && mv /tmp/dbs database/seeders/DatabaseSeeder.php

# Optimize & migrate
run "php artisan config:clear"
run "php artisan route:clear"
run "php artisan view:clear"
run "php artisan migrate --force"
run "php artisan db:seed --force"

echo "[+] Done. Go to /settings."
