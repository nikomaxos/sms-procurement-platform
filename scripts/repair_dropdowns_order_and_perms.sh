#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

echo "==> Step 0: backup and remove conflicting dropdown migrations (same timestamp)"
mkdir -p database/migrations/_bak
for f in database/migrations/*create_dropdown_{menus,items}_table.php; do
  [ -f "$f" ] && mv -v "$f" "database/migrations/_bak/$(basename "$f").bak.$(date +%F_%H-%M-%S)"
done

# Generate two distinct timestamps: menus first, items second
T0=$(date +%s)
TS1=$(date -d "@$((T0))" +%Y_%m_%d_%H%M%S)
TS2=$(date -d "@$((T0+2))" +%Y_%m_%d_%H%M%S)

echo "==> Step 1: write ordered migrations (menus -> items)"
cat > "database/migrations/${TS1}_create_dropdown_menus_table.php" <<'PHP'
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

cat > "database/migrations/${TS2}_create_dropdown_items_table.php" <<'PHP'
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

echo "==> Step 2: ensure models/controllers/views already created (leave as-is if present)"
# (No-op: your previous run wrote them; we won’t overwrite here.)

echo "==> Step 3: ensure routes are present and no legacy DropDownController remains"
ROUTES="routes/web.php"
cp -a "$ROUTES" "$ROUTES.bak.$(date +%F_%H-%M-%S)"

# Remove any old DropDownController route lines (just in case)
perl -0777 -i -pe "s~^\\s*Route::get\\(\\s*['\"]/settings/dropdowns['\"]\\s*,[^;]*;\\s*\\n~~mg" "$ROUTES"

# Ensure our group is present (append if missing)
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

    // Items
    Route::get('/{menu}/items', [\App\Http\Controllers\Settings\DropdownItemController::class, 'index'])->name('items.index');
    Route::post('/{menu}/items', [\App\Http\Controllers\Settings\DropdownItemController::class, 'store'])->name('items.store');
    Route::get('/{menu}/items/{item}/edit', [\App\Http\Controllers\Settings\DropdownItemController::class, 'edit'])->name('items.edit');
    Route::put('/{menu}/items/{item}', [\App\Http\Controllers\Settings\DropdownItemController::class, 'update'])->name('items.update');
    Route::delete('/{menu}/items/{item}', [\App\Http\Controllers\Settings\DropdownItemController::class, 'destroy'])->name('items.destroy');
});
PHP
fi

echo "==> Step 4: inside container: fix permissions, clear caches, migrate, recache"
$DC exec -T app bash -lc '
  set -e
  chown -R www-data:www-data storage bootstrap/cache || true
  chmod -R ug+rwX storage bootstrap/cache || true

  composer dump-autoload -o

  php artisan optimize:clear || true
  php artisan config:clear || true
  php artisan route:clear || true
  php artisan view:clear || true

  php artisan migrate --force

  php artisan view:cache || true
  php artisan route:cache || true
  php artisan config:cache || true
'

echo "==> Step 5: forbid standard users from deleting their account"
PC="app/Http/Controllers/ProfileController.php"
if [ -f "$PC" ]; then
  # Insert guard at start of destroy() if not present
  perl -0777 -i -pe "
    if (!/Account deletion is restricted to admins\\./) {
      s{
        (public\\s+function\\s+destroy\\s*\\(\\s*Request\\s+\\$request\\s*\\)\\s*\\{)
      }{
        \\1
        if ((auth()->user()->role ?? 'standard') !== 'admin') {
            return back()->with('error', 'Account deletion is restricted to admins.');
        }
      }sx;
    }
    $_;
  " "$PC" || true
fi

echo "==> All done. Go to: /settings/dropdowns"
