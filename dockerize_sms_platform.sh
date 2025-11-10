#!/usr/bin/env bash
# ---------------------------------------------------------------------------------
# SMS Procurement Platform — Laravel Bootstrap (core + Settings + dropdown CRUD)
# ---------------------------------------------------------------------------------
# What this script does (idempotent):
# 1) Creates a fresh Laravel app in the current repo (or upgrades an existing one)
# 2) Installs Breeze auth (Blade), seeds an admin user, enables a Settings area
# 3) Adds three dropdown-maintained lookups with full CRUD:
#    - Route Type (Direct, HQ, SS7, SIM, Local Bypass)
#    - Known Hops (0-Hop, 1-Hop, 2-Hops, N-Hops)
#    - Charge Model (Per Submit, Per Delivered)
# 4) Wires navigation links, gates (admin only), and seeds initial values
# 5) Uses SQLite by default for zero-config local dev, changeable later to Postgres
#
# Usage:
#   1) cd into your cloned repo (e.g., sms-procurement-platform)
#   2) bash bootstrap_sms_platform.sh
#   3) php artisan serve   # then open http://127.0.0.1:8000
#      Login with: admin@example.com / secret  (customize via .env -> ADMIN_EMAIL/PASSWORD)
# ---------------------------------------------------------------------------------

set -Eeuo pipefail
shopt -s nullglob

log(){ printf "\n[+] %s\n" "$*"; }
warn(){ printf "\n[!] %s\n" "$*"; }
err(){ printf "\n[x] %s\n" "$*"; }

require(){ command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }; }

require php
require composer

if [ ! -d .git ]; then
  warn "This folder does not look like a git repo (no .git). Proceeding anyway."
fi

TS=$(date +%F_%H-%M-%S)
BACKUP=".backup_before_bootstrap_${TS}.tgz"
log "Creating safety backup archive: ${BACKUP} (excluding vendor, node_modules, .git)"
tar --exclude-vcs --exclude=vendor --exclude=node_modules -czf "$BACKUP" . || true

# ---------------------------------------------------------------------------------
# 1) Create or ensure a Laravel app exists in this directory
# ---------------------------------------------------------------------------------
if [ ! -f artisan ]; then
  log "No artisan found — creating a new Laravel app here."
  rm -rf .tmp_laravel || true
  composer create-project laravel/laravel .tmp_laravel >/dev/null
  rsync -a .tmp_laravel/ ./
  rm -rf .tmp_laravel
else
  log "Laravel already present. Skipping framework scaffold."
fi

# ---------------------------------------------------------------------------------
# 2) .env and key
# ---------------------------------------------------------------------------------
if [ ! -f .env ]; then
  cp .env.example .env
fi

# Switch to SQLite by default for smooth local boot.
php -r '
$env=file_get_contents(".env");
$env=preg_replace("/^DB_CONNECTION=.*/m","DB_CONNECTION=sqlite",$env);
$env=preg_replace("/^DB_HOST=.*/m","# DB_HOST=127.0.0.1",$env);
$env=preg_replace("/^DB_PORT=.*/m","# DB_PORT=5432",$env);
$env=preg_replace("/^DB_DATABASE=.*/m","# DB_DATABASE=app",$env);
$env=preg_replace("/^DB_USERNAME=.*/m","# DB_USERNAME=app",$env);
$env=preg_replace("/^DB_PASSWORD=.*/m","# DB_PASSWORD=secret",$env);
if(!str_contains($env,"ADMIN_EMAIL")){$env.="\nADMIN_EMAIL=admin@example.com\n";}
if(!str_contains($env,"ADMIN_PASSWORD")){$env.="ADMIN_PASSWORD=secret\n";}
if(!str_contains($env,"APP_URL")){$env.="APP_URL=http://127.0.0.1:8000\n";}
file_put_contents(".env",$env);
'

mkdir -p database
:> database/database.sqlite

php artisan key:generate --force >/dev/null

# ---------------------------------------------------------------------------------
# 3) Install auth (Breeze) + Excel library for later imports
# ---------------------------------------------------------------------------------
log "Installing Laravel Breeze (auth scaffolding)"
composer require laravel/breeze --dev -q
php artisan breeze:install blade -q

log "Installing maatwebsite/excel (for future Excel import)"
composer require maatwebsite/excel:^3.1 -q

# ---------------------------------------------------------------------------------
# 4) Minimal user admin flag & seed admin user
# ---------------------------------------------------------------------------------
log "Adding is_admin flag to users table"
php artisan make:migration add_is_admin_to_users_table --table=users -q
ADM_MIG=$(ls database/migrations/*_add_is_admin_to_users_table.php | head -n1)
cat > "$ADM_MIG" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_admin')->default(false)->after('password');
        });
    }
    public function down(): void {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('is_admin');
        });
    }
};
PHP

log "Generating dropdown models & migrations"
php artisan make:model RouteType -m -q
php artisan make:model KnownHop  -m -q
php artisan make:model ChargeModel -m -q

RT_MIG=$(ls database/migrations/*create_route_types_table.php | head -n1)
KH_MIG=$(ls database/migrations/*create_known_hops_table.php | head -n1)
CM_MIG=$(ls database/migrations/*create_charge_models_table.php | head -n1)

cat > "$RT_MIG" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('route_types', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('slug')->unique();
            $table->timestamps();
        });
    }
    public function down(): void { Schema::dropIfExists('route_types'); }
};
PHP

cat > "$KH_MIG" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('known_hops', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('slug')->unique();
            $table->timestamps();
        });
    }
    public function down(): void { Schema::dropIfExists('known_hops'); }
};
PHP

cat > "$CM_MIG" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('charge_models', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('slug')->unique();
            $table->timestamps();
        });
    }
    public function down(): void { Schema::dropIfExists('charge_models'); }
};
PHP

log "Creating seeders"
php artisan make:seeder DropdownSeeder -q
php artisan make:seeder AdminUserSeeder -q

cat > database/seeders/DropdownSeeder.php <<'PHP'
<?php
namespace Database\Seeders;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;
use App\Models\RouteType;
use App\Models\KnownHop;
use App\Models\ChargeModel;

class DropdownSeeder extends Seeder
{
    public function run(): void
    {
        $routeTypes = ['Direct','HQ','SS7','SIM','Local Bypass'];
        foreach ($routeTypes as $n) {
            RouteType::firstOrCreate(['slug'=>Str::slug($n)], ['name'=>$n]);
        }

        $knownHops = ['0-Hop','1-Hop','2-Hops','N-Hops'];
        foreach ($knownHops as $n) {
            KnownHop::firstOrCreate(['slug'=>Str::slug($n)], ['name'=>$n]);
        }

        $chargeModels = ['Per Submit','Per Delivered'];
        foreach ($chargeModels as $n) {
            ChargeModel::firstOrCreate(['slug'=>Str::slug($n)], ['name'=>$n]);
        }
    }
}
PHP

cat > database/seeders/AdminUserSeeder.php <<'PHP'
<?php
namespace Database\Seeders;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use App\Models\User;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $email = env('ADMIN_EMAIL', 'admin@example.com');
        $password = env('ADMIN_PASSWORD', 'secret');
        $user = User::firstOrCreate([
            'email' => $email,
        ], [
            'name' => 'Administrator',
            'password' => Hash::make($password),
        ]);
        if (! $user->is_admin) {
            $user->is_admin = true;
            $user->save();
        }
    }
}
PHP

cat > database/seeders/DatabaseSeeder.php <<'PHP'
<?php
namespace Database\Seeders;
use Illuminate\Database\Seeder;
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            AdminUserSeeder::class,
            DropdownSeeder::class,
        ]);
    }
}
PHP

# ---------------------------------------------------------------------------------
# 5) Models fillable
# ---------------------------------------------------------------------------------
cat > app/Models/RouteType.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
class RouteType extends Model
{
    use HasFactory;
    protected $fillable = ['name','slug'];
}
PHP

cat > app/Models/KnownHop.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
class KnownHop extends Model
{
    use HasFactory;
    protected $fillable = ['name','slug'];
}
PHP

cat > app/Models/ChargeModel.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
class ChargeModel extends Model
{
    use HasFactory;
    protected $fillable = ['name','slug'];
}
PHP

# ---------------------------------------------------------------------------------
# 6) Gates and Controllers
# ---------------------------------------------------------------------------------
log "Defining admin Gate and creating controllers"
perl -0777 -pe "s/public function boot\(\): void\n\{\n\s*\}/public function boot\(\): void\n{\n    \Illuminate\\Support\\Facades\\Gate::define('admin', fn(\$user) => (bool) \$user->is_admin);\n}/s" -i app/Providers/AuthServiceProvider.php || true

php artisan make:controller SettingsController -q
php artisan make:controller Admin/UserController --resource -q
php artisan make:controller Admin/RouteTypeController --resource --model=RouteType -q
php artisan make:controller Admin/KnownHopController  --resource --model=KnownHop  -q
php artisan make:controller Admin/ChargeModelController --resource --model=ChargeModel -q

cat > app/Http/Controllers/SettingsController.php <<'PHP'
<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
class SettingsController extends Controller
{
    public function __construct(){ $this->middleware('auth'); }
    public function index(){ return view('settings.index'); }
}
PHP

cat > app/Http/Controllers/Admin/UserController.php <<'PHP'
<?php
namespace App\Http\Controllers\Admin;
use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function __construct(){
        $this->middleware(['auth','can:admin']);
    }

    public function index(){
        $users = User::orderBy('id','asc')->paginate(20);
        return view('admin.users.index', compact('users'));
    }

    public function create(){ return view('admin.users.create'); }

    public function store(Request $request){
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|string|min:6|confirmed',
            'is_admin' => 'sometimes|boolean',
        ]);
        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
            'is_admin' => (bool)($data['is_admin'] ?? false),
        ]);
        return redirect()->route('admin.users.index')->with('status','User created');
    }

    public function edit(User $user){ return view('admin.users.edit', compact('user')); }

    public function update(Request $request, User $user){
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => ['required','email', Rule::unique('users','email')->ignore($user->id)],
            'password' => 'nullable|string|min:6|confirmed',
            'is_admin' => 'sometimes|boolean',
        ]);
        $user->name = $data['name'];
        $user->email = $data['email'];
        if (!empty($data['password'])) { $user->password = Hash::make($data['password']); }
        $user->is_admin = (bool)($data['is_admin'] ?? false);
        $user->save();
        return redirect()->route('admin.users.index')->with('status','User updated');
    }

    public function destroy(User $user){
        if (auth()->id() === $user->id) { return back()->with('status','Cannot delete yourself'); }
        $user->delete();
        return redirect()->route('admin.users.index')->with('status','User deleted');
    }
}
PHP

# CRUD base controller template generator
mk_crud(){
  local CLASS=$1 MODEL=$2 VIEW=$3
  cat > "app/Http/Controllers/Admin/${CLASS}.php" <<PHP
<?php
namespace App\\Http\\Controllers\\Admin;
use App\\Http\\Controllers\\Controller;
use App\\Models\\${MODEL};
use Illuminate\\Http\\Request;
use Illuminate\\Support\\Str;

class ${CLASS} extends Controller
{
    public function __construct(){ \$this->middleware(['auth','can:admin']); }
    public function index(){ \$items=${MODEL}::orderBy('name')->paginate(20); return view('${VIEW}.index', compact('items')); }
    public function create(){ return view('${VIEW}.create'); }
    public function store(Request \$request){
        \$data = \$request->validate(['name'=>'required|string|max:100']);
        \$slug = Str::slug(\$data['name']);
        ${MODEL}::create(['name'=>\$data['name'],'slug'=>\$slug]);
        return redirect()->route('${VIEW}.index')->with('status','Saved');
    }
    public function edit(${MODEL} \$item){ return view('${VIEW}.edit', compact('item')); }
    public function update(Request \$request, ${MODEL} \$item){
        \$data = \$request->validate(['name'=>'required|string|max:100']);
        \$item->update(['name'=>\$data['name'], 'slug'=>Str::slug(\$data['name'])]);
        return redirect()->route('${VIEW}.index')->with('status','Updated');
    }
    public function destroy(${MODEL} \$item){ \$item->delete(); return redirect()->route('${VIEW}.index')->with('status','Deleted'); }
}
PHP
}

mk_crud RouteTypeController RouteType admin.route_types
mk_crud KnownHopController  KnownHop  admin.known_hops
mk_crud ChargeModelController ChargeModel admin.charge_models

# ---------------------------------------------------------------------------------
# 7) Views (Blade)
# ---------------------------------------------------------------------------------
mkdir -p resources/views/{settings,admin/users,admin/route_types,admin/known_hops,admin/charge_models,components}

# Tiny alert component
cat > resources/views/components/alert.blade.php <<'BLADE'
@if(session('status'))
<div class="bg-green-50 border border-green-200 text-green-800 rounded p-3 mb-4">{{ session('status') }}</div>
@endif
BLADE

# Settings landing
cat > resources/views/settings/index.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">Settings</h2>
    </x-slot>
    <div class="py-6">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8 space-y-6">
            <x-alert />
            <div class="bg-white p-6 shadow sm:rounded-lg">
                <div class="flex gap-4 flex-wrap">
                    <a href="{{ route('profile.edit') }}" class="px-4 py-2 bg-gray-100 rounded hover:bg-gray-200">My Profile</a>
                    @can('admin')
                    <a href="{{ route('admin.users.index') }}" class="px-4 py-2 bg-gray-100 rounded hover:bg-gray-200">Users</a>
                    <a href="{{ route('admin.route_types.index') }}" class="px-4 py-2 bg-gray-100 rounded hover:bg-gray-200">Drop‑down Menus → Route Types</a>
                    <a href="{{ route('admin.known_hops.index') }}" class="px-4 py-2 bg-gray-100 rounded hover:bg-gray-200">Drop‑down Menus → Known Hops</a>
                    <a href="{{ route('admin.charge_models.index') }}" class="px-4 py-2 bg-gray-100 rounded hover:bg-gray-200">Drop‑down Menus → Charge Models</a>
                    @endcan
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
BLADE

# Users views
cat > resources/views/admin/users/index.blade.php <<'BLADE'
<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">Users</h2></x-slot>
    <div class="py-6">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8">
            <x-alert />
            <div class="bg-white p-6 shadow sm:rounded-lg">
                <div class="flex justify-between mb-4">
                    <div></div>
                    <a href="{{ route('admin.users.create') }}" class="px-4 py-2 bg-indigo-600 text-white rounded">New User</a>
                </div>
                <table class="w-full text-left">
                    <thead><tr class="border-b"><th class="py-2">ID</th><th>Name</th><th>Email</th><th>Admin</th><th class="text-right">Actions</th></tr></thead>
                    <tbody>
                        @foreach($users as $u)
                        <tr class="border-b">
                            <td class="py-2">{{ $u->id }}</td>
                            <td>{{ $u->name }}</td>
                            <td>{{ $u->email }}</td>
                            <td>{{ $u->is_admin ? 'Yes' : 'No' }}</td>
                            <td class="text-right">
                                <a class="px-3 py-1 bg-gray-100 rounded" href="{{ route('admin.users.edit',$u) }}">Edit</a>
                                @if(auth()->id() !== $u->id)
                                <form method="POST" action="{{ route('admin.users.destroy',$u) }}" class="inline" onsubmit="return confirm('Delete user?')">
                                    @csrf @method('DELETE')
                                    <button class="px-3 py-1 bg-red-600 text-white rounded">Delete</button>
                                </form>
                                @endif
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
                <div class="mt-4">{{ $users->links() }}</div>
            </div>
        </div>
    </div>
</x-app-layout>
BLADE

cat > resources/views/admin/users/create.blade.php <<'BLADE'
<x-app-layout>
<x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">New User</h2></x-slot>
<div class="py-6"><div class="max-w-2xl mx-auto sm:px-6 lg:px-8"><div class="bg-white p-6 shadow sm:rounded-lg">
    <form method="POST" action="{{ route('admin.users.store') }}" class="space-y-4">
        @csrf
        <div><label class="block">Name <input name="name" class="mt-1 w-full border rounded p-2" required></label></div>
        <div><label class="block">Email <input type="email" name="email" class="mt-1 w-full border rounded p-2" required></label></div>
        <div><label class="block">Password <input type="password" name="password" class="mt-1 w-full border rounded p-2" required></label></div>
        <div><label class="block">Confirm Password <input type="password" name="password_confirmation" class="mt-1 w-full border rounded p-2" required></label></div>
        <div class="flex items-center gap-2"><input type="checkbox" name="is_admin" value="1" id="is_admin"><label for="is_admin">Admin</label></div>
        <div class="pt-4"><button class="px-4 py-2 bg-indigo-600 text-white rounded">Save</button></div>
    </form>
</div></div></div>
</x-app-layout>
BLADE

cat > resources/views/admin/users/edit.blade.php <<'BLADE'
<x-app-layout>
<x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">Edit User</h2></x-slot>
<div class="py-6"><div class="max-w-2xl mx-auto sm:px-6 lg:px-8"><div class="bg-white p-6 shadow sm:rounded-lg">
    <form method="POST" action="{{ route('admin.users.update',$user) }}" class="space-y-4">
        @csrf @method('PUT')
        <div><label class="block">Name <input name="name" value="{{ old('name',$user->name) }}" class="mt-1 w-full border rounded p-2" required></label></div>
        <div><label class="block">Email <input type="email" name="email" value="{{ old('email',$user->email) }}" class="mt-1 w-full border rounded p-2" required></label></div>
        <div><label class="block">Password (optional) <input type="password" name="password" class="mt-1 w-full border rounded p-2"></label></div>
        <div><label class="block">Confirm Password <input type="password" name="password_confirmation" class="mt-1 w-full border rounded p-2"></label></div>
        <div class="flex items-center gap-2"><input type="checkbox" name="is_admin" value="1" id="is_admin" {{ $user->is_admin ? 'checked' : '' }}><label for="is_admin">Admin</label></div>
        <div class="pt-4"><button class="px-4 py-2 bg-indigo-600 text-white rounded">Update</button></div>
    </form>
</div></div></div>
</x-app-layout>
BLADE

# Generic CRUD views factory
mk_views(){
  local DIR=$1 TITLE=$2 LABEL=$3
  cat > resources/views/${DIR}/index.blade.php <<BLADE
<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">${TITLE}</h2></x-slot>
    <div class="py-6">
      <div class="max-w-4xl mx-auto sm:px-6 lg:px-8">
        <x-alert />
        <div class="bg-white p-6 shadow sm:rounded-lg">
          <div class="flex justify-between mb-4">
            <div></div>
            <a href="{{ route('${DIR}.create') }}" class="px-4 py-2 bg-indigo-600 text-white rounded">New</a>
          </div>
          <table class="w-full text-left">
            <thead><tr class="border-b"><th class="py-2">${LABEL}</th><th>Slug</th><th class="text-right">Actions</th></tr></thead>
            <tbody>
              @foreach(\$items as \$item)
              <tr class="border-b">
                <td class="py-2">{{ \$item->name }}</td>
                <td>{{ \$item->slug }}</td>
                <td class="text-right">
                  <a class="px-3 py-1 bg-gray-100 rounded" href="{{ route('${DIR}.edit', \$item) }}">Edit</a>
                  <form method="POST" action="{{ route('${DIR}.destroy', \$item) }}" class="inline" onsubmit="return confirm('Delete?')">
                    @csrf @method('DELETE')
                    <button class="px-3 py-1 bg-red-600 text-white rounded">Delete</button>
                  </form>
                </td>
              </tr>
              @endforeach
            </tbody>
          </table>
          <div class="mt-4">{{ \$items->links() }}</div>
        </div>
      </div>
    </div>
</x-app-layout>
BLADE

  cat > resources/views/${DIR}/create.blade.php <<BLADE
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">New ${TITLE}</h2></x-slot>
  <div class="py-6"><div class="max-w-xl mx-auto sm:px-6 lg:px-8"><div class="bg-white p-6 shadow sm:rounded-lg">
    <form method="POST" action="{{ route('${DIR}.store') }}" class="space-y-4">
      @csrf
      <div><label class="block">${LABEL}<input name="name" class="mt-1 w-full border rounded p-2" required></label></div>
      <div class="pt-4"><button class="px-4 py-2 bg-indigo-600 text-white rounded">Save</button></div>
    </form>
  </div></div></div>
</x-app-layout>
BLADE

  cat > resources/views/${DIR}/edit.blade.php <<BLADE
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">Edit ${TITLE}</h2></x-slot>
  <div class="py-6"><div class="max-w-xl mx-auto sm:px-6 lg:px-8"><div class="bg-white p-6 shadow sm:rounded-lg">
    <form method="POST" action="{{ route('${DIR}.update', \$item) }}" class="space-y-4">
      @csrf @method('PUT')
      <div><label class="block">${LABEL}<input name="name" value="{{ old('name', \$item->name) }}" class="mt-1 w-full border rounded p-2" required></label></div>
      <div class="pt-4"><button class="px-4 py-2 bg-indigo-600 text-white rounded">Update</button></div>
    </form>
  </div></div></div>
</x-app-layout>
BLADE
}

mk_views admin/route_types "Route Types" "Name"
mk_views admin/known_hops  "Known Hops"  "Name"
mk_views admin/charge_models "Charge Models" "Name"

# ---------------------------------------------------------------------------------
# 8) Routes & Navigation
# ---------------------------------------------------------------------------------
log "Wiring routes"
cat > routes/web.php <<'PHP'
<?php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\Admin\UserController;
use App\Http\Controllers\Admin\RouteTypeController;
use App\Http\Controllers\Admin\KnownHopController;
use App\Http\Controllers\Admin\ChargeModelController;

Route::get('/', function () { return view('welcome'); });

Route::middleware('auth')->group(function () {
    Route::get('/dashboard', function () { return view('dashboard'); })->name('dashboard');
    Route::get('/settings', [SettingsController::class, 'index'])->name('settings.index');

    // Profile (Breeze)
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

    // Admin-only
    Route::middleware('can:admin')->prefix('settings')->name('admin.')->group(function(){
        Route::resource('users', UserController::class)->except(['show']);
        Route::resource('route-types', RouteTypeController::class)->parameters(['route-types'=>'item'])->names('route_types');
        Route::resource('known-hops', KnownHopController::class)->parameters(['known-hops'=>'item'])->names('known_hops');
        Route::resource('charge-models', ChargeModelController::class)->parameters(['charge-models'=>'item'])->names('charge_models');
    });
});

require __DIR__.'/auth.php';
PHP

# Patch Breeze navigation to include Settings
NAV="resources/views/layouts/navigation.blade.php"
if [ -f "$NAV" ]; then
  perl -0777 -pe "s#</div>\s*</div>\s*</div>\s*</nav>#  <div class=\"hidden sm:-my-px sm:ms-10 sm:flex\">\n      <a href=\"{{ route('settings.index') }}\" class=\"inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium leading-5 text-gray-500 hover:text-gray-700 focus:outline-none transition duration-150 ease-in-out\">Settings</a>\n  </div>\n</div>\n</div>\n</div>\n</nav>#s" -i "$NAV" || true
fi

# ---------------------------------------------------------------------------------
# 9) Migrate & Seed
# ---------------------------------------------------------------------------------
log "Running migrations & seeders"
php artisan migrate --force
php artisan db:seed --force

# ---------------------------------------------------------------------------------
# 10) Frontend build (optional)
# ---------------------------------------------------------------------------------
if command -v npm >/dev/null 2>&1; then
  log "Building Breeze frontend assets (npm)"
  npm install --silent
  npm run build --silent || true
else
  warn "npm not found — skipping asset build. UI will work but be minimally styled until you run npm install && npm run dev/build."
fi

log "All set. Start the app:  php artisan serve"
log "Login with admin@example.com / secret (customize in .env)"


#!/usr/bin/env bash
# ---------------------------------------------------------------------------------
# dockerize_sms_platform.sh — Containerize Laravel (PHP-FPM + Nginx + Postgres)
# Repo root: ~/sms-procurement-platform
# ---------------------------------------------------------------------------------
# What this does (idempotent):
#  - Writes docker-compose.yml, Dockerfiles, Nginx vhost, .dockerignore, Makefile
#  - Creates .env.docker with Postgres settings (keeps your existing .env intact)
#  - Builds containers, runs composer install, generates app key, migrates & seeds
#  - Exposes web on http://localhost:8080
# Usage:
#   cd ~/sms-procurement-platform
#   bash dockerize_sms_platform.sh
#   open http://localhost:8080   (login: admin@example.com / secret)
# ---------------------------------------------------------------------------------
set -Eeuo pipefail
shopt -s nullglob

log(){ printf "
[+] %s
" "$*"; }
warn(){ printf "
[!] %s
" "$*"; }
err(){ printf "
[x] %s
" "$*"; }

ROOT_DIR=$(pwd)
[[ -f artisan ]] || { err "artisan not found. Run this inside the Laravel project root."; exit 1; }

# Safety backup of current docker files if exist
TS=$(date +%F_%H-%M-%S)
BACKUP_DIR=.backup_docker_${TS}
mkdir -p "$BACKUP_DIR"
for f in docker-compose.yml docker .dockerignore Makefile .env.docker; do
  [[ -e "$f" ]] && cp -r "$f" "$BACKUP_DIR/" || true
done
[[ -d "$BACKUP_DIR" && -n $(ls -A "$BACKUP_DIR" 2>/dev/null || true) ]] && log "Backed up existing docker assets to $BACKUP_DIR" || true

# .dockerignore — keep images lean
cat > .dockerignore <<'IGNORE'
.git
vendor
node_modules
storage/logs
storage/framework/cache
storage/framework/sessions
storage/framework/views
.env
IGNORE

# Docker structure
mkdir -p docker/app docker/nginx

# Dockerfile (PHP-FPM)
cat > docker/app/Dockerfile <<'DOCKER'
FROM php:8.4-fpm

# System deps
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git unzip libicu-dev libpq-dev libzip-dev libpng-dev libonig-dev \
      libjpeg-dev libfreetype6-dev \
 && rm -rf /var/lib/apt/lists/*

# PHP extensions
RUN docker-php-ext-configure intl \
 && docker-php-ext-install -j$(nproc) intl mbstring pcntl zip exif \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j$(nproc) gd \
 && docker-php-ext-install -j$(nproc) pdo_pgsql

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
# Keep www-data uid/gid predictable for volume mounts
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data || true

# Default php.ini tweaks
RUN { \
  echo "memory_limit=512M"; \
  echo "upload_max_filesize=64M"; \
  echo "post_max_size=64M"; \
  echo "max_execution_time=120"; \
} > /usr/local/etc/php/conf.d/zz-app.ini

CMD ["php-fpm"]
DOCKER

# Nginx vhost
cat > docker/nginx/default.conf <<'NGINX'
server {
    listen 80;
    server_name _;

    root /var/www/html/public;
    index index.php index.html;

    access_log /var/log/nginx/access.log; 
    error_log  /var/log/nginx/error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass app:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_read_timeout 300;
    }

    location ~* \.(?:ico|css|js|gif|jpe?g|png|svg|woff2?)$ {
        expires 7d;
        access_log off;
    }
}
NGINX

# docker-compose.yml
cat > docker-compose.yml <<'YML'
version: "3.9"

services:
  postgres:
    image: postgres:15
    container_name: sms-platform-postgres
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
    volumes:
      - dbdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app -h localhost"]
      interval: 10s
      timeout: 5s
      retries: 10

  app:
    build: ./docker/app
    container_name: sms-platform-app
    working_dir: /var/www/html
    volumes:
      - .:/var/www/html
      - vendor:/var/www/html/vendor
      - node_modules:/var/www/html/node_modules
    env_file: .env.docker
    depends_on:
      postgres:
        condition: service_healthy

  web:
    image: nginx:1.27-alpine
    container_name: sms-platform-web
    ports:
      - "8080:80"
    volumes:
      - .:/var/www/html:ro
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app

  # Optional helper to build assets without installing Node on host
  node:
    image: node:20-bookworm-slim
    working_dir: /var/www/html
    volumes:
      - .:/var/www/html
    entrypoint: ["bash", "-lc"]
    command: ["npm ci && npm run build"]

volumes:
  dbdata:
  vendor:
  node_modules:
YML

# .env.docker — do not overwrite if already customized
if [[ ! -f .env.docker ]]; then
  log "Creating .env.docker"
  cp .env .env.docker || true
  php -r '
  $p = ".env.docker"; $env = file_exists($p)?file_get_contents($p):"";
  $set = function($k,$v) use (&$env){ $env=preg_replace("/^{$k}=.*$/m","{$k}={$v}",$env)?:$env."
{$k}={$v}
"; };
  $set("APP_ENV","local");
  $set("APP_DEBUG","true");
  $set("APP_URL","http://localhost:8080");
  $set("DB_CONNECTION","pgsql");
  $set("DB_HOST","postgres");
  $set("DB_PORT","5432");
  $set("DB_DATABASE","app");
  $set("DB_USERNAME","app");
  $set("DB_PASSWORD","secret");
  $set("SESSION_DRIVER","file");
  $set("QUEUE_CONNECTION","database");
  file_put_contents($p,$env);
  '
fi

# Makefile for handy commands
cat > Makefile <<'MAKE'
SHELL := /bin/bash

up: ## Build & start stack
	docker compose up -d --build

stop: ## Stop stack
	docker compose stop

down: ## Stop & remove containers (keep volumes)
	docker compose down

logs: ## Tail logs
	docker compose logs -f --tail=200

sh: ## Shell into app container
	docker compose exec app bash

composer-install:
	docker compose run --rm app composer install --no-interaction --prefer-dist

key:
	docker compose exec app php artisan key:generate --force

migrate:
	docker compose exec app php artisan migrate --force

seed:
	docker compose exec app php artisan db:seed --force

fresh:
	docker compose exec app php artisan migrate:fresh --seed --force

assets:
	docker compose run --rm node "npm ci && npm run build"

init: up composer-install key migrate seed assets ## First-time init
MAKE

# Bring stack up and initialize
log "Starting containers (build)"
docker compose up -d --build

log "Installing PHP dependencies (composer)"
docker compose run --rm app composer install --no-interaction --prefer-dist

log "Generating APP_KEY"
docker compose exec app php artisan key:generate --force

log "Running migrations & seeders (admin user + dropdowns)"
docker compose exec app php artisan migrate --force
docker compose exec app php artisan db:seed --force

# Optional: build assets if package.json exists
if [[ -f package.json ]]; then
  log "Building frontend assets (Node container)"
  docker compose run --rm node "npm ci && npm run build" || warn "Asset build skipped/failed; UI will work with minimal styling."
fi

log "All set. Open http://localhost:8080"
log "Login → admin@example.com / secret (change later in Settings → Users)"
