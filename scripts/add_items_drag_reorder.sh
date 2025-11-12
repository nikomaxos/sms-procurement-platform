#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

TS_NOW=$(date +%s)
MIG_TS=$(date -d "@$((TS_NOW+5))" +%Y_%m_%d_%H%M%S)

############################################
# 1) Migration: add position to items table
############################################
mkdir -p database/migrations
cat > "database/migrations/${MIG_TS}_add_position_to_dropdown_items.php" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasColumn('dropdown_items', 'position')) {
            Schema::table('dropdown_items', function (Blueprint $table) {
                $table->integer('position')->default(0)->index();
            });
            // Backfill existing rows with sequential positions per menu
            $pos = [];
            foreach (DB::table('dropdown_items')->orderBy('dropdown_menu_id')->orderBy('id')->cursor() as $row) {
                $m = $row->dropdown_menu_id;
                $pos[$m] = ($pos[$m] ?? 0) + 1;
                DB::table('dropdown_items')->where('id', $row->id)->update(['position' => $pos[$m]]);
            }
        }
    }
    public function down(): void {
        if (Schema::hasColumn('dropdown_items', 'position')) {
            Schema::table('dropdown_items', function (Blueprint $table) {
                $table->dropColumn('position');
            });
        }
    }
};
PHP

############################################
# 2) Ensure Models exist (simple fillables)
############################################
mkdir -p app/Models
[ -f app/Models/DropdownMenu.php ] || cat > app/Models/DropdownMenu.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;

class DropdownMenu extends Model {
    protected $fillable = ['title'];
    public function items(){ return $this->hasMany(DropdownItem::class); }
}
PHP

[ -f app/Models/DropdownItem.php ] || cat > app/Models/DropdownItem.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;

class DropdownItem extends Model {
    protected $fillable = ['dropdown_menu_id','label','position'];
    public function menu(){ return $this->belongsTo(DropdownMenu::class,'dropdown_menu_id'); }
}
PHP

########################################################
# 3) Controller: add reorder() and order by position asc
########################################################
mkdir -p app/Http/Controllers/Settings
cat > app/Http/Controllers/Settings/DropdownItemController.php <<'PHP'
<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\DropdownMenu;
use App\Models\DropdownItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class DropdownItemController extends Controller {

    public function __construct(){
        $this->middleware('auth');
    }

    public function index(DropdownMenu $menu){
        $items = DropdownItem::where('dropdown_menu_id',$menu->id)
            ->orderBy('position')->orderBy('id')
            ->get();
        return view('settings.dropdowns.items.index', compact('menu','items'));
    }

    public function store(Request $request, DropdownMenu $menu){
        $data = $request->validate([
            'label' => ['required','string','max:255'],
        ]);
        $max = DropdownItem::where('dropdown_menu_id',$menu->id)->max('position') ?? 0;
        DropdownItem::create([
            'dropdown_menu_id' => $menu->id,
            'label' => $data['label'],
            'position' => $max + 1,
        ]);
        return back()->with('status','Item created');
    }

    public function edit(DropdownMenu $menu, DropdownItem $item){
        abort_unless($item->dropdown_menu_id === $menu->id, 404);
        return view('settings.dropdowns.items.edit', compact('menu','item'));
    }

    public function update(Request $request, DropdownMenu $menu, DropdownItem $item){
        abort_unless($item->dropdown_menu_id === $menu->id, 404);
        $data = $request->validate([
            'label' => ['required','string','max:255'],
        ]);
        $item->update(['label'=>$data['label']]);
        return redirect()->route('settings.dropdowns.items.index', $menu)->with('status','Item updated');
    }

    public function destroy(DropdownMenu $menu, DropdownItem $item){
        abort_unless($item->dropdown_menu_id === $menu->id, 404);
        $item->delete();
        return back()->with('status','Item deleted');
    }

    public function reorder(Request $request, DropdownMenu $menu){
        $data = $request->validate([
            'order' => ['required','array','min:1'],
            'order.*' => ['integer','distinct']
        ]);

        $ids = $data['order'];
        // verify all ids belong to the menu
        $count = DropdownItem::where('dropdown_menu_id',$menu->id)->whereIn('id',$ids)->count();
        if ($count !== count($ids)) {
            return response()->json(['ok'=>false,'message'=>'Invalid items set'], 422);
        }

        DB::transaction(function() use ($ids, $menu) {
            $pos = 0;
            foreach ($ids as $id) {
                $pos++;
                DropdownItem::where('id',$id)
                    ->where('dropdown_menu_id',$menu->id)
                    ->update(['position'=>$pos]);
            }
        });

        return response()->json(['ok'=>true]);
    }
}
PHP

############################################
# 4) Items index view with DnD + Save order
############################################
mkdir -p resources/views/settings/dropdowns/items
cat > resources/views/settings/dropdowns/items/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">
      Drop Down: {{ $menu->title }} — Items
    </h2>
  </x-slot>

  <div class="max-w-4xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-700 px-3 py-2">
        {{ session('status') }}
      </div>
    @endif

    <form method="POST" action="{{ route('settings.dropdowns.items.store', $menu) }}" class="mb-6 flex gap-2">
      @csrf
      <input name="label" class="border rounded px-3 py-2 w-full" placeholder="New item label..." required>
      <button class="rounded bg-blue-600 text-white px-4 py-2 hover:bg-blue-700">Add</button>
    </form>

    <div class="mb-2 text-sm text-gray-600">
      Drag items to reorder. Changes save automatically.
    </div>

    <ul id="sortable-list" class="bg-white border rounded divide-y">
      @foreach ($items as $item)
        <li class="flex items-center justify-between gap-3 px-3 py-2"
            data-id="{{ $item->id }}" draggable="true">
          <div class="flex items-center gap-2">
            <span class="cursor-grab select-none" aria-hidden="true">⋮⋮</span>
            <span>{{ $item->label }}</span>
          </div>
          <div class="flex items-center gap-2">
            <a href="{{ route('settings.dropdowns.items.edit', [$menu, $item]) }}"
               class="text-sm px-2 py-1 border rounded hover:bg-gray-50">Edit</a>
            <form method="POST" action="{{ route('settings.dropdowns.items.destroy', [$menu, $item]) }}"
                  onsubmit="return confirm('Delete this item?')">
              @csrf @method('DELETE')
              <button class="text-sm px-2 py-1 border rounded hover:bg-gray-50">Delete</button>
            </form>
          </div>
        </li>
      @endforeach
    </ul>

    <div id="save-status" class="mt-3 hidden text-sm"></div>

    <div class="mt-8">
      <a href="{{ route('settings.dropdowns.index') }}" class="text-sm text-blue-700 hover:underline">← Back to all menus</a>
    </div>
  </div>

  <script src="{{ asset('js/dnd-reorder.js') }}" defer></script>
</x-app-layout>
BLADE

############################################
# 5) DnD JS (CSP-safe, external file)
############################################
mkdir -p public/js
cat > public/js/dnd-reorder.js <<'JS'
(function(){
  function $(sel){ return document.querySelector(sel); }
  const list = $("#sortable-list");
  if(!list) return;

  let dragEl = null;
  list.addEventListener("dragstart", (e)=>{
    const li = e.target.closest("li[draggable=true]");
    if(!li) return;
    dragEl = li;
    e.dataTransfer.effectAllowed = "move";
    e.dataTransfer.setData("text/plain", li.dataset.id);
    li.classList.add("opacity-50");
  });
  list.addEventListener("dragend", (e)=>{
    if(dragEl) dragEl.classList.remove("opacity-50");
    dragEl = null;
  });
  list.addEventListener("dragover", (e)=>{
    e.preventDefault();
    const li = e.target.closest("li[draggable=true]");
    if(!li || li===dragEl) return;
    const rect = li.getBoundingClientRect();
    const before = (e.clientY - rect.top) < rect.height/2;
    list.insertBefore(dragEl, before ? li : li.nextSibling);
  });
  list.addEventListener("drop", (e)=>{
    e.preventDefault();
    saveOrder();
  });

  function saveOrder(){
    const ids = Array.from(list.querySelectorAll("li[draggable=true]"))
                .map(li => parseInt(li.dataset.id,10));
    const status = document.getElementById("save-status");
    const meta = document.querySelector('meta[name="csrf-token"]');
    const csrf = meta ? meta.getAttribute("content") : "";

    // Infer reorder URL from the first "Edit" link (same menu scope)
    const editLink = list.querySelector('a[href*="/settings/dropdowns/"][href*="/items/"]');
    if(!editLink){ return; }
    const m = editLink.href.match(/^(https?:\/\/[^/]+)?\/settings\/dropdowns\/(\d+)/);
    if(!m){ return; }
    const menuId = m[2];
    const url = `/settings/dropdowns/${menuId}/items/reorder`;

    fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-TOKEN": csrf,
        "Accept": "application/json"
      },
      body: JSON.stringify({order: ids})
    })
    .then(r => r.json())
    .then(j => {
      if(j && j.ok){
        status.className = "mt-3 text-sm text-green-700";
        status.textContent = "Order saved.";
      }else{
        status.className = "mt-3 text-sm text-red-700";
        status.textContent = "Failed to save order.";
      }
      setTimeout(()=>{ status.classList.add("hidden"); }, 1500);
      status.classList.remove("hidden");
    })
    .catch(()=> {
      status.className = "mt-3 text-sm text-red-700";
      status.textContent = "Failed to save order.";
      status.classList.remove("hidden");
      setTimeout(()=>{ status.classList.add("hidden"); }, 2000);
    });
  }
})();
JS

############################################
# 6) Route for reorder (auth)
############################################
ROUTES="routes/web.php"
cp -a "$ROUTES" "$ROUTES.bak.$(date +%F_%H-%M-%S)"
if ! grep -q "settings.dropdowns.items.reorder" "$ROUTES"; then
  cat >> "$ROUTES" <<'PHP'

Route::post(
  '/settings/dropdowns/{menu}/items/reorder',
  [\App\Http\Controllers\Settings\DropdownItemController::class, 'reorder']
)->middleware('auth')->name('settings.dropdowns.items.reorder');
PHP
fi

############################################
# 7) Fix permissions, migrate, clear caches
############################################
$DC exec -T app bash -lc '
  set -e
  chown -R www-data:www-data storage bootstrap/cache || true
  chmod -R ug+rwX storage bootstrap/cache || true

  composer dump-autoload -o

  php artisan optimize:clear || true
  php artisan migrate --force

  php artisan route:cache || true
  php artisan view:cache || true
  php artisan config:cache || true
'

echo "==> Drag-and-drop ordering enabled. Open the Items page and drag rows; order saves automatically."
