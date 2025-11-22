#!/usr/bin/env bash
set -euo pipefail

echo "==> add_product_type_to_connections: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# ---------------------------------------------------------------------------
# 1) Create migration for product_type on supplier_connections
# ---------------------------------------------------------------------------
MIGRATION_TS="$(date +"%Y_%m_%d_%H%M%S")"
MIGRATION_FILE="database/migrations/${MIGRATION_TS}_add_product_type_to_supplier_connections_table.php"

if [[ -f "$MIGRATION_FILE" ]]; then
  echo "!! Migration file already exists: $MIGRATION_FILE"
else
  cat > "$MIGRATION_FILE" << 'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('supplier_connections', 'product_type')) {
            Schema::table('supplier_connections', function (Blueprint $table) {
                $table->string('product_type')
                    ->nullable()
                    ->after('charge_type');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('supplier_connections', 'product_type')) {
            Schema::table('supplier_connections', function (Blueprint $table) {
                $table->dropColumn('product_type');
            });
        }
    }
};
PHP
  echo "==> Created migration: $MIGRATION_FILE"
fi

# ---------------------------------------------------------------------------
# 2) Rewrite app/Models/SupplierConnection.php
# ---------------------------------------------------------------------------
cat > app/Models/SupplierConnection.php << 'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SupplierConnection extends Model
{
    use HasFactory;

    protected $fillable = [
        'supplier_id',
        'name',
        'username',
        'charge_type',
        'product_type',
        'notes',
    ];

    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }
}
PHP
echo "==> Updated app/Models/SupplierConnection.php"

# ---------------------------------------------------------------------------
# 3) Rewrite app/Http/Controllers/SupplierConnectionsController.php
# ---------------------------------------------------------------------------
cat > app/Http/Controllers/SupplierConnectionsController.php << 'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\Supplier;
use App\Models\SupplierConnection;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

class SupplierConnectionsController extends Controller
{
    public function create(Supplier $supplier): View
    {
        $productTypeOptions = $this->getProductTypeOptions();

        return view('suppliers.connections.create', [
            'supplier'           => $supplier,
            'productTypeOptions' => $productTypeOptions,
        ]);
    }

    public function store(Request $request, Supplier $supplier): RedirectResponse
    {
        $data = $this->validateData($request);

        $connection = new SupplierConnection($data);
        $connection->supplier()->associate($supplier);
        $connection->save();

        return redirect()
            ->route('suppliers.show', $supplier)
            ->with('status', 'Connection created.');
    }

    public function edit(Supplier $supplier, SupplierConnection $connection): View
    {
        if ($connection->supplier_id !== $supplier->id) {
            abort(404);
        }

        $productTypeOptions = $this->getProductTypeOptions();

        return view('suppliers.connections.edit', [
            'supplier'           => $supplier,
            'connection'         => $connection,
            'productTypeOptions' => $productTypeOptions,
        ]);
    }

    public function update(Request $request, Supplier $supplier, SupplierConnection $connection): RedirectResponse
    {
        if ($connection->supplier_id !== $supplier->id) {
            abort(404);
        }

        $data = $this->validateData($request);

        $connection->update($data);

        return redirect()
            ->route('suppliers.show', $supplier)
            ->with('status', 'Connection updated.');
    }

    public function destroy(Supplier $supplier, SupplierConnection $connection): RedirectResponse
    {
        if ($connection->supplier_id !== $supplier->id) {
            abort(404);
        }

        $connection->delete();

        return redirect()
            ->route('suppliers.show', $supplier)
            ->with('status', 'Connection deleted.');
    }

    protected function validateData(Request $request): array
    {
        return $request->validate([
            'name'         => ['required', 'string', 'max:255'],
            'username'     => ['nullable', 'string', 'max:255'],
            'charge_type'  => ['required', 'in:per_submit,per_delivered'],
            'product_type' => ['nullable', 'string', 'max:255'],
            'notes'        => ['nullable', 'string'],
        ]);
    }

    /**
     * Resolve "Product Type" options from the Drop Down Menus module.
     *
     * [Inference] This uses defensive heuristics because we cannot see your
     * actual dropdown models / tables from here. If the list is empty in
     * the UI, adjust this method to match your real schema.
     */
    protected function getProductTypeOptions(): array
    {
        try {
            // Heuristic 1: a Dropdown model with a relation like items/options/values
            if (class_exists(\App\Models\Dropdown::class)) {
                /** @var \App\Models\Dropdown $menu */
                $menuQuery = \App\Models\Dropdown::query();

                $menu = $menuQuery
                    ->where('name', 'Product Type')
                    ->orWhere('slug', 'product_type')
                    ->first();

                if ($menu) {
                    foreach (['items', 'options', 'values'] as $relation) {
                        if (method_exists($menu, $relation)) {
                            $items = $menu->{$relation}()->get();
                            $options = [];

                            foreach ($items as $item) {
                                $data = $item->toArray();

                                $label = $data['label'] ?? $data['name'] ?? $data['title'] ?? null;
                                $value = $data['value'] ?? $data['key'] ?? $data['code'] ?? $label;

                                if ($label === null) {
                                    continue;
                                }

                                $options[$value] = $label;
                            }

                            if (! empty($options)) {
                                return $options;
                            }
                        }
                    }
                }
            }

            // Heuristic 2: a generic dropdown_options table keyed by menu_name
            if (DB::getSchemaBuilder()->hasTable('dropdown_options')) {
                $rows = DB::table('dropdown_options')
                    ->where('menu_name', 'Product Type')
                    ->orderBy('position')
                    ->get();

                $options = [];

                foreach ($rows as $row) {
                    $label = $row->label ?? $row->name ?? null;
                    $value = $row->value ?? $row->key ?? $row->code ?? $label;

                    if ($label === null) {
                        continue;
                    }

                    $options[$value] = $label;
                }

                if (! empty($options)) {
                    return $options;
                }
            }
        } catch (\Throwable $e) {
            // Fail-safe: never break the page if the schema is different.
        }

        return [];
    }
}
PHP
echo "==> Updated app/Http/Controllers/SupplierConnectionsController.php"

# ---------------------------------------------------------------------------
# 4) Rewrite views for create & edit connection
# ---------------------------------------------------------------------------

mkdir -p resources/views/suppliers/connections

# -- create.blade.php -------------------------------------------------------
cat > resources/views/suppliers/connections/create.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            New Connection for {{ $supplier->name }}
        </h2>
    </x-slot>

    <div class="py-6">
        <div class="max-w-3xl mx-auto sm:px-6 lg:px-8">
            <div class="bg-white overflow-hidden shadow-sm sm:rounded-lg">
                <div class="p-6 text-gray-900">
                    <form method="POST" action="{{ route('suppliers.connections.store', $supplier) }}" class="space-y-6">
                        @csrf

                        {{-- Connection Name --}}
                        <div>
                            <label for="name" class="block text-sm font-medium text-gray-700">
                                Connection Name
                            </label>
                            <input
                                id="name"
                                name="name"
                                type="text"
                                value="{{ old('name') }}"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                                required
                            />
                            @error('name')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Username --}}
                        <div>
                            <label for="username" class="block text-sm font-medium text-gray-700">
                                Username
                            </label>
                            <input
                                id="username"
                                name="username"
                                type="text"
                                value="{{ old('username') }}"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            />
                            @error('username')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Charge Type --}}
                        <div>
                            <label for="charge_type" class="block text-sm font-medium text-gray-700">
                                Charge Type
                            </label>
                            <select
                                id="charge_type"
                                name="charge_type"
                                class="mt-1 block w-full rounded-md border-gray-300 bg-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                                required
                            >
                                <option value="">-- Select Charge Type --</option>
                                <option value="per_submit" {{ old('charge_type') === 'per_submit' ? 'selected' : '' }}>
                                    Per Submit
                                </option>
                                <option value="per_delivered" {{ old('charge_type') === 'per_delivered' ? 'selected' : '' }}>
                                    Per Delivered
                                </option>
                            </select>
                            @error('charge_type')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Product Type (dynamic from Drop Down Menus) --}}
                        <div>
                            <label for="product_type" class="block text-sm font-medium text-gray-700">
                                Product Type
                            </label>
                            <select
                                id="product_type"
                                name="product_type"
                                class="mt-1 block w-full rounded-md border-gray-300 bg-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            >
                                <option value="">-- Select Product Type --</option>
                                @forelse($productTypeOptions as $value => $label)
                                    <option value="{{ $value }}" {{ old('product_type') == $value ? 'selected' : '' }}>
                                        {{ $label }}
                                    </option>
                                @empty
                                    <option value="" disabled>-- No product types defined yet --</option>
                                @endforelse
                            </select>
                            @error('product_type')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror

                            @if(empty($productTypeOptions))
                                <p class="mt-2 text-xs text-gray-500">
                                    Define "Product Type" values under <strong>Settings → Drop Down Menus</strong>
                                    and they will automatically appear here.
                                </p>
                            @endif
                        </div>

                        {{-- Notes --}}
                        <div>
                            <label for="notes" class="block text-sm font-medium text-gray-700">
                                Notes
                            </label>
                            <textarea
                                id="notes"
                                name="notes"
                                rows="4"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            >{{ old('notes') }}</textarea>
                            @error('notes')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        <div class="flex items-center justify-end gap-3">
                            <a href="{{ route('suppliers.show', $supplier) }}"
                               class="inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50">
                                Cancel
                            </a>

                            <button type="submit"
                                    class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                                Save Connection
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
BLADE
echo "==> Wrote resources/views/suppliers/connections/create.blade.php"

# -- edit.blade.php ---------------------------------------------------------
cat > resources/views/suppliers/connections/edit.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Edit Connection: {{ $connection->name }} ({{ $supplier->name }})
        </h2>
    </x-slot>

    <div class="py-6">
        <div class="max-w-3xl mx-auto sm:px-6 lg:px-8">
            <div class="bg-white overflow-hidden shadow-sm sm:rounded-lg">
                <div class="p-6 text-gray-900">
                    <form method="POST" action="{{ route('suppliers.connections.update', [$supplier, $connection]) }}" class="space-y-6">
                        @csrf
                        @method('PUT')

                        {{-- Connection Name --}}
                        <div>
                            <label for="name" class="block text-sm font-medium text-gray-700">
                                Connection Name
                            </label>
                            <input
                                id="name"
                                name="name"
                                type="text"
                                value="{{ old('name', $connection->name) }}"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                                required
                            />
                            @error('name')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Username --}}
                        <div>
                            <label for="username" class="block text-sm font-medium text-gray-700">
                                Username
                            </label>
                            <input
                                id="username"
                                name="username"
                                type="text"
                                value="{{ old('username', $connection->username) }}"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            />
                            @error('username')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Charge Type --}}
                        <div>
                            <label for="charge_type" class="block text-sm font-medium text-gray-700">
                                Charge Type
                            </label>
                            <select
                                id="charge_type"
                                name="charge_type"
                                class="mt-1 block w-full rounded-md border-gray-300 bg-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                                required
                            >
                                @php
                                    $currentChargeType = old('charge_type', $connection->charge_type);
                                @endphp
                                <option value="">-- Select Charge Type --</option>
                                <option value="per_submit" {{ $currentChargeType === 'per_submit' ? 'selected' : '' }}>
                                    Per Submit
                                </option>
                                <option value="per_delivered" {{ $currentChargeType === 'per_delivered' ? 'selected' : '' }}>
                                    Per Delivered
                                </option>
                            </select>
                            @error('charge_type')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Product Type (dynamic from Drop Down Menus) --}}
                        <div>
                            <label for="product_type" class="block text-sm font-medium text-gray-700">
                                Product Type
                            </label>
                            @php
                                $currentProductType = old('product_type', $connection->product_type);
                            @endphp
                            <select
                                id="product_type"
                                name="product_type"
                                class="mt-1 block w-full rounded-md border-gray-300 bg-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            >
                                <option value="">-- Select Product Type --</option>
                                @forelse($productTypeOptions as $value => $label)
                                    <option value="{{ $value }}" {{ (string)$currentProductType === (string)$value ? 'selected' : '' }}>
                                        {{ $label }}
                                    </option>
                                @empty
                                    <option value="" disabled>-- No product types defined yet --</option>
                                @endforelse
                            </select>
                            @error('product_type')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror

                            @if(empty($productTypeOptions))
                                <p class="mt-2 text-xs text-gray-500">
                                    Define "Product Type" values under <strong>Settings → Drop Down Menus</strong>
                                    and they will automatically appear here.
                                </p>
                            @endif
                        </div>

                        {{-- Notes --}}
                        <div>
                            <label for="notes" class="block text-sm font-medium text-gray-700">
                                Notes
                            </label>
                            <textarea
                                id="notes"
                                name="notes"
                                rows="4"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            >{{ old('notes', $connection->notes) }}</textarea>
                            @error('notes')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        <div class="flex items-center justify-end gap-3">
                            <a href="{{ route('suppliers.show', $supplier) }}"
                               class="inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50">
                                Cancel
                            </a>

                            <button type="submit"
                                    class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                                Update Connection
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
BLADE
echo "==> Wrote resources/views/suppliers/connections/edit.blade.php"

# ---------------------------------------------------------------------------
# 5) Run migrations & clear caches inside the app container
# ---------------------------------------------------------------------------
echo "==> Running migrations inside docker 'app' service"
docker compose exec -T app php artisan migrate --force

echo "==> Clearing Laravel caches (optimize:clear)"
docker compose exec -T app php artisan optimize:clear

echo "==> add_product_type_to_connections: done"
