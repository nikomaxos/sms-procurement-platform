#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

TS="$(date +%Y_%m_%d_%H%M%S)"

########################################
# 1) Migrations: dropdown_menus & items
########################################
mkdir -p database/migrations

cat > "database/migrations/${TS}_create_dropdown_menus_table.php" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasTable('dropdown_menus')) {
            Schema::create('dropdown_menus', function (Blueprint $table) {
                $table->id();
                $table->string('title', 120);
                $table->timestamps();
            });
        }
    }
    public function down(): void {
        Schema::dropIfExists('dropdown_menus');
    }
};
PHP

cat > "database/migrations/${TS}_create_dropdown_items_table.php" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasTable('dropdown_items')) {
            Schema::create('dropdown_items', function (Blueprint $table) {
                $table->id();
                $table->foreignId('dropdown_menu_id')->constrained('dropdown_menus')->cascadeOnDelete();
                $table->string('label', 255);
                $table->timestamps();
            });
        }
    }
    public function down(): void {
        Schema::dropIfExists('dropdown_items');
    }
};
PHP

##########################
# 2) Eloquent Models
##########################
mkdir -p app/Models

cat > app/Models/DropdownMenu.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DropdownMenu extends Model
{
    protected $fillable = ['title'];

    public function items(): HasMany {
        return $this->hasMany(DropdownItem::class);
    }
}
PHP

cat > app/Models/DropdownItem.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DropdownItem extends Model
{
    protected $fillable = ['label', 'dropdown_menu_id'];

    public function menu(): BelongsTo {
        return $this->belongsTo(DropdownMenu::class, 'dropdown_menu_id');
    }
}
PHP

########################################
# 3) Controllers (menus + items)
########################################
mkdir -p app/Http/Controllers/Settings

cat > app/Http/Controllers/Settings/DropdownMenuController.php <<'PHP'
<?php

namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\DropdownMenu;
use Illuminate\Http\Request;

class DropdownMenuController extends Controller
{
    public function __construct() {
        $this->middleware('auth');
    }

    public function index() {
        $menus = DropdownMenu::query()->withCount('items')->orderBy('id', 'desc')->paginate(20);
        return view('settings.dropdowns.index', compact('menus'));
    }

    public function create() {
        return view('settings.dropdowns.create');
    }

    public function store(Request $request) {
        $data = $request->validate([
            'title' => ['required','string','max:120'],
        ]);
        $menu = DropdownMenu::create($data);
        return redirect()->route('settings.dropdowns.items.index', $menu)->with('status', 'menu-created');
    }

    public function edit(DropdownMenu $menu) {
        return view('settings.dropdowns.edit', compact('menu'));
    }

    public function update(Request $request, DropdownMenu $menu) {
        $data = $request->validate([
            'title' => ['required','string','max:120'],
        ]);
        $menu->update($data);
        return redirect()->route('settings.dropdowns.index')->with('status', 'menu-updated');
    }

    public function destroy(DropdownMenu $menu) {
        $menu->delete();
        return redirect()->route('settings.dropdowns.index')->with('status', 'menu-deleted');
    }
}
PHP

cat > app/Http/Controllers/Settings/DropdownItemController.php <<'PHP'
<?php

namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\DropdownItem;
use App\Models\DropdownMenu;
use Illuminate\Http\Request;

class DropdownItemController extends Controller
{
    public function __construct() {
        $this->middleware('auth');
    }

    // Manage items in a single menu
    public function index(DropdownMenu $menu) {
        $items = $menu->items()->orderBy('id', 'asc')->paginate(50);
        return view('settings.dropdowns.items.index', compact('menu','items'));
    }

    public function store(Request $request, DropdownMenu $menu) {
        $data = $request->validate([
            'label' => ['required','string','max:255'],
        ]);
        $menu->items()->create($data);
        return redirect()->route('settings.dropdowns.items.index', $menu)->with('status', 'item-created');
    }

    public function edit(DropdownMenu $menu, DropdownItem $item) {
        // Ensure item belongs to menu
        abort_unless($item->dropdown_menu_id === $menu->id, 404);
        return view('settings.dropdowns.items.edit', compact('menu','item'));
    }

    public function update(Request $request, DropdownMenu $menu, DropdownItem $item) {
        abort_unless($item->dropdown_menu_id === $menu->id, 404);
        $data = $request->validate([
            'label' => ['required','string','max:255'],
        ]);
        $item->update($data);
        return redirect()->route('settings.dropdowns.items.index', $menu)->with('status', 'item-updated');
    }

    public function destroy(DropdownMenu $menu, DropdownItem $item) {
        abort_unless($item->dropdown_menu_id === $menu->id, 404);
        $item->delete();
        return redirect()->route('settings.dropdowns.items.index', $menu)->with('status', 'item-deleted');
    }
}
PHP

#############################
# 4) Blade Views (Tailwind)
#############################
mkdir -p resources/views/settings/dropdowns/items

# Menus: index
cat > resources/views/settings/dropdowns/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Drop Down Menus</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="mb-4">
      <a href="{{ route('settings.dropdowns.create') }}"
         class="inline-flex items-center rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 text-sm">
        + New Menu
      </a>
    </div>

    <div class="overflow-hidden rounded-lg border bg-white">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-2 text-left font-semibold text-gray-700">ID</th>
            <th class="px-4 py-2 text-left font-semibold text-gray-700">Title</th>
            <th class="px-4 py-2 text-left font-semibold text-gray-700">Items</th>
            <th class="px-4 py-2 text-right font-semibold text-gray-700">Actions</th>
          </tr>
        </thead>
        <tbody>
        @forelse($menus as $menu)
          <tr class="border-t">
            <td class="px-4 py-2 text-gray-800">{{ $menu->id }}</td>
            <td class="px-4 py-2 text-gray-800">{{ $menu->title }}</td>
            <td class="px-4 py-2 text-gray-800">{{ $menu->items_count }}</td>
            <td class="px-4 py-2">
              <div class="flex items-center gap-2 justify-end">
                <a href="{{ route('settings.dropdowns.items.index', $menu) }}"
                   class="rounded border px-3 py-1.5 text-gray-700 hover:bg-gray-50">Manage items</a>
                <a href="{{ route('settings.dropdowns.edit', $menu) }}"
                   class="rounded border px-3 py-1.5 text-gray-700 hover:bg-gray-50">Edit</a>
                <form method="POST" action="{{ route('settings.dropdowns.destroy', $menu) }}"
                      onsubmit="return confirm('Delete this menu (and its items)?');">
                  @csrf @method('DELETE')
                  <button class="rounded border px-3 py-1.5 text-red-600 hover:bg-red-50">Delete</button>
                </form>
              </div>
            </td>
          </tr>
        @empty
          <tr class="border-t">
            <td colspan="4" class="px-4 py-6 text-center text-gray-500">No menus yet. Create one.</td>
          </tr>
        @endforelse
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $menus->links() }}</div>
  </div>
</x-app-layout>
BLADE

# Menus: create
cat > resources/views/settings/dropdowns/create.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">New Drop Down Menu</h2>
  </x-slot>

  <div class="py-6 max-w-xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="rounded-lg border bg-white p-6">
      <form method="POST" action="{{ route('settings.dropdowns.store') }}" class="space-y-4">
        @csrf
        <div>
          <label class="block text-sm font-medium text-gray-700">Title</label>
          <input name="title" value="{{ old('title') }}" class="mt-1 w-full rounded border px-3 py-2" required maxlength="120">
          @error('title')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
        </div>
        <div class="flex items-center gap-2">
          <a href="{{ route('settings.dropdowns.index') }}" class="rounded border px-4 py-2 text-gray-700 hover:bg-gray-50">Cancel</a>
          <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Create</button>
        </div>
      </form>
    </div>
  </div>
</x-app-layout>
BLADE

# Menus: edit
cat > resources/views/settings/dropdowns/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Menu</h2>
  </x-slot>

  <div class="py-6 max-w-xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="rounded-lg border bg-white p-6">
      <form method="POST" action="{{ route('settings.dropdowns.update', $menu) }}" class="space-y-4">
        @csrf @method('PUT')
        <div>
          <label class="block text-sm font-medium text-gray-700">Title</label>
          <input name="title" value="{{ old('title', $menu->title) }}" class="mt-1 w-full rounded border px-3 py-2" required maxlength="120">
          @error('title')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
        </div>
        <div class="flex items-center gap-2">
          <a href="{{ route('settings.dropdowns.index') }}" class="rounded border px-4 py-2 text-gray-700 hover:bg-gray-50">Back</a>
          <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        </div>
      </form>
    </div>
  </div>
</x-app-layout>
BLADE

# Items: index (manage items for a menu)
cat > resources/views/settings/dropdowns/items/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">
      Items — {{ $menu->title }}
    </h2>
  </x-slot>

  <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">

    <div class="flex items-center justify-between">
      <a href="{{ route('settings.dropdowns.index') }}" class="text-sm text-gray-700 hover:text-gray-900">&larr; Back to menus</a>
      <form method="POST" action="{{ route('settings.dropdowns.items.store', $menu) }}" class="flex items-center gap-2">
        @csrf
        <input name="label" placeholder="New item label" class="rounded border px-3 py-2 text-sm" required maxlength="255">
        <button class="rounded bg-blue-600 px-3 py-2 text-sm text-white hover:bg-blue-700">Add</button>
      </form>
    </div>

    <div class="overflow-hidden rounded-lg border bg-white">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-2 text-left font-semibold text-gray-700">ID</th>
            <th class="px-4 py-2 text-left font-semibold text-gray-700">Label</th>
            <th class="px-4 py-2 text-right font-semibold text-gray-700">Actions</th>
          </tr>
        </thead>
        <tbody>
        @forelse($items as $item)
          <tr class="border-t">
            <td class="px-4 py-2 text-gray-800">{{ $item->id }}</td>
            <td class="px-4 py-2 text-gray-800">{{ $item->label }}</td>
            <td class="px-4 py-2">
              <div class="flex items-center gap-2 justify-end">
                <a href="{{ route('settings.dropdowns.items.edit', [$menu, $item]) }}"
                   class="rounded border px-3 py-1.5 text-gray-700 hover:bg-gray-50">Edit</a>
                <form method="POST" action="{{ route('settings.dropdowns.items.destroy', [$menu, $item]) }}"
                      onsubmit="return confirm('Delete this item?');">
                  @csrf @method('DELETE')
                  <button class="rounded border px-3 py-1.5 text-red-600 hover:bg-red-50">Delete</button>
                </form>
              </div>
            </td>
          </tr>
        @empty
          <tr class="border-t">
            <td colspan="3" class="px-4 py-6 text-center text-gray-500">No items yet.</td>
          </tr>
        @endforelse
        </tbody>
      </table>
    </div>

    <div class="mt-2">{{ $items->links() }}</div>
  </div>
</x-app-layout>
BLADE

# Items: edit
cat > resources/views/settings/dropdowns/items/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">
      Edit Item — {{ $menu->title }}
    </h2>
  </x-slot>

  <div class="py-6 max-w-xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="rounded-lg border bg-white p-6">
      <form method="POST" action="{{ route('settings.dropdowns.items.update', [$menu, $item]) }}" class="space-y-4">
        @csrf @method('PUT')
        <div>
          <label class="block text-sm font-medium text-gray-700">Label</label>
          <input name="label" value="{{ old('label', $item->label) }}" class="mt-1 w-full rounded border px-3 py-2" required maxlength="255">
          @error('label')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
        </div>
        <div class="flex items-center gap-2">
          <a href="{{ route('settings.dropdowns.items.index', $menu) }}" class="rounded border px-4 py-2 text-gray-700 hover:bg-gray-50">Back</a>
          <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        </div>
      </form>
    </div>
  </div>
</x-app-layout>
BLADE

########################################
# 5) Routes: replace old dropdowns line
########################################
ROUTES="routes/web.php"
cp -a "$ROUTES" "$ROUTES.bak.$(date +%F_%H-%M-%S)"

# Remove any simple GET /settings/dropdowns route (old placeholder)
perl -0777 -i -pe "s~^\\s*Route::get\\(\\s*['\"]/settings/dropdowns['\"]\\s*,[^;]*;\\s*\\n~~mg" "$ROUTES"

# Ensure imports (use statements) for new controllers if you keep them at top — not strictly required if we FQCN below.
# Append our group if missing
if ! grep -q "settings.dropdowns.items.index" "$ROUTES"; then
cat >> "$ROUTES" <<'PHP'

// Drop Down Menus + Items (auth)
Route::middleware(['auth'])->prefix('settings/dropdowns')->name('settings.dropdowns.')->group(function () {
    // Menus
    Route::get('/', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'index'])->name('index');
    Route::get('/create', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'create'])->name('create');
    Route::post('/', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'store'])->name('store');
    Route::get('/{menu}/edit', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'edit'])->name('edit');
    Route::put('/{menu}', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'update'])->name('update');
    Route::delete('/{menu}', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'destroy'])->name('destroy');

    // Items (within a menu)
    Route::get('/{menu}/items', [\App\Http\Controllers\Settings\DropdownItemController::class, 'index'])->name('items.index');
    Route::post('/{menu}/items', [\App\Http\Controllers\Settings\DropdownItemController::class, 'store'])->name('items.store');
    Route::get('/{menu}/items/{item}/edit', [\App\Http\Controllers\Settings\DropdownItemController::class, 'edit'])->name('items.edit');
    Route::put('/{menu}/items/{item}', [\App\Http\Controllers\Settings\DropdownItemController::class, 'update'])->name('items.update');
    Route::delete('/{menu}/items/{item}', [\App\Http\Controllers\Settings\DropdownItemController::class, 'destroy'])->name('items.destroy');
});
PHP
fi

########################################
# 6) Build autoload, migrate, cache
########################################
$DC exec -T app bash -lc '
  set -e
  composer dump-autoload -o
  php artisan migrate --force
  php artisan optimize:clear || true
  php artisan view:clear || true
  php artisan view:cache || true
  php artisan route:cache || true
'

echo "==> Drop Down Menus & Items installed."
echo "   • Menus: /settings/dropdowns (index, create, edit, delete)"
echo "   • Items: /settings/dropdowns/{menu}/items (add/edit/delete)"
