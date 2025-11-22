#!/usr/bin/env bash
set -euo pipefail

echo "==> add_connection_dead_field_v1: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/add_connection_dead_field_${STAMP}"
echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "   - Backing up ${f}"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    cp "$f" "${BACKUP_DIR}/${f}"
  fi
}

backup_file "app/Models/SupplierConnection.php"
backup_file "app/Http/Controllers/SupplierConnectionsController.php"
backup_file "resources/views/suppliers/connections/create.blade.php"
backup_file "resources/views/suppliers/connections/edit.blade.php"
backup_file "resources/views/suppliers/show.blade.php"

# ---------------------------------------------------------------------------
# 1) Migration: add connection_dead to supplier_connections
# ---------------------------------------------------------------------------
MIG_TS="$(date +"%Y_%m_%d_%H%M%S")"
MIG_FILE="database/migrations/${MIG_TS}_add_connection_dead_to_supplier_connections_table.php"

cat > "$MIG_FILE" << 'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('supplier_connections', 'connection_dead')) {
            Schema::table('supplier_connections', function (Blueprint $table) {
                $table->boolean('connection_dead')
                    ->default(false)
                    ->after('product_type');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('supplier_connections', 'connection_dead')) {
            Schema::table('supplier_connections', function (Blueprint $table) {
                $table->dropColumn('connection_dead');
            });
        }
    }
};
PHP
echo "==> Created migration: $MIG_FILE"

# ---------------------------------------------------------------------------
# 2) SupplierConnection model: add connection_dead
# ---------------------------------------------------------------------------
cat > app/Models/SupplierConnection.php << 'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SupplierConnection extends Model
{
    use HasFactory;

    public const CHARGE_TYPE_PER_SUBMIT    = 'per_submit';
    public const CHARGE_TYPE_PER_DELIVERED = 'per_delivered';

    public static function chargeTypeOptions(): array
    {
        return [
            self::CHARGE_TYPE_PER_SUBMIT    => 'Per Submit',
            self::CHARGE_TYPE_PER_DELIVERED => 'Per Delivered',
        ];
    }

    protected $fillable = [
        'supplier_id',
        'name',
        'username',
        'charge_type',
        'product_type',
        'connection_dead',
        'notes',
    ];

    protected $casts = [
        'connection_dead' => 'boolean',
    ];

    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }

    public function getChargeTypeLabelAttribute(): string
    {
        return static::chargeTypeOptions()[$this->charge_type] ?? (string) $this->charge_type;
    }
}
PHP
echo "==> Rewrote app/Models/SupplierConnection.php"

# ---------------------------------------------------------------------------
# 3) SupplierConnectionsController: handle connection_dead
# ---------------------------------------------------------------------------
cat > app/Http/Controllers/SupplierConnectionsController.php << 'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\Supplier;
use App\Models\SupplierConnection;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SupplierConnectionsController extends Controller
{
    public function create(Supplier $supplier)
    {
        $productTypeOptions = $this->getProductTypeOptions();

        return view('suppliers.connections.create', [
            'supplier'           => $supplier,
            'productTypeOptions' => $productTypeOptions,
        ]);
    }

    public function store(Request $request, Supplier $supplier)
    {
        $data = $this->validateData($request);

        $connection = new SupplierConnection($data);
        $connection->supplier()->associate($supplier);
        $connection->save();

        return redirect()
            ->route('suppliers.show', $supplier)
            ->with('status', 'Connection created.');
    }

    public function edit(Supplier $supplier, SupplierConnection $connection)
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

    public function update(Request $request, Supplier $supplier, SupplierConnection $connection)
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

    public function destroy(Supplier $supplier, SupplierConnection $connection)
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
        $data = $request->validate([
            'name'         => ['required', 'string', 'max:255'],
            'username'     => ['nullable', 'string', 'max:255'],
            'charge_type'  => [
                'required',
                'string',
                'in:' . implode(',', array_keys(SupplierConnection::chargeTypeOptions())),
            ],
            'product_type'    => ['nullable', 'string', 'max:255'],
            'connection_dead' => ['sometimes', 'boolean'],
            'notes'           => ['nullable', 'string'],
        ]);

        // Normalize checkbox into a true boolean
        $data['connection_dead'] = $request->boolean('connection_dead');

        return $data;
    }

    /**
     * Load Product Type options from the Drop Down Menus.
     *
     * Assumptions:
     *   - Product Type menu is dropdown_menu_id = 1
     *   - Items table is dropdown_items with: id, dropdown_menu_id, label, (optional) position
     * Values stored in SupplierConnection.product_type will be the label string.
     */
    protected function getProductTypeOptions(): array
    {
        try {
            $schema = DB::getSchemaBuilder();

            if (! $schema->hasTable('dropdown_items')) {
                return [];
            }

            $menuId = 1;

            $query = DB::table('dropdown_items')
                ->where('dropdown_menu_id', $menuId);

            if ($schema->hasColumn('dropdown_items', 'position')) {
                $query->orderBy('position');
            }

            if ($schema->hasColumn('dropdown_items', 'label')) {
                $query->orderBy('label');
            }

            $rows = $query->get();

            $options = [];
            foreach ($rows as $row) {
                $label = $row->label ?? null;
                if ($label === null || $label === '') {
                    continue;
                }

                $options[$label] = $label;
            }

            return $options;
        } catch (\Throwable $e) {
            return [];
        }
    }
}
PHP
echo "==> Rewrote app/Http/Controllers/SupplierConnectionsController.php"

# ---------------------------------------------------------------------------
# 4) Update create/edit views: add Connection Dead checkbox
# ---------------------------------------------------------------------------

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

                        {{-- Connection Dead --}}
                        @php
                            $isDead = filter_var(old('connection_dead', '0'), FILTER_VALIDATE_BOOLEAN);
                        @endphp
                        <div class="flex items-center">
                            <input
                                id="connection_dead"
                                name="connection_dead"
                                type="checkbox"
                                value="1"
                                class="h-4 w-4 text-red-600 border-gray-300 rounded focus:ring-red-500"
                                @checked($isDead)
                            />
                            <label for="connection_dead" class="ml-2 block text-sm text-gray-700">
                                Connection Dead
                            </label>
                        </div>
                        @error('connection_dead')
                        <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                        @enderror

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
echo "==> Rewrote resources/views/suppliers/connections/create.blade.php"

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
                            @php
                                $currentChargeType = old('charge_type', $connection->charge_type);
                            @endphp
                            <select
                                id="charge_type"
                                name="charge_type"
                                class="mt-1 block w-full rounded-md border-gray-300 bg-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                                required
                            >
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

                        {{-- Connection Dead --}}
                        @php
                            $isDead = filter_var(
                                old('connection_dead', $connection->connection_dead ? '1' : '0'),
                                FILTER_VALIDATE_BOOLEAN
                            );
                        @endphp
                        <div class="flex items-center">
                            <input
                                id="connection_dead"
                                name="connection_dead"
                                type="checkbox"
                                value="1"
                                class="h-4 w-4 text-red-600 border-gray-300 rounded focus:ring-red-500"
                                @checked($isDead)
                            />
                            <label for="connection_dead" class="ml-2 block text-sm text-gray-700">
                                Connection Dead
                            </label>
                        </div>
                        @error('connection_dead')
                        <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                        @enderror

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
echo "==> Rewrote resources/views/suppliers/connections/edit.blade.php"

# ---------------------------------------------------------------------------
# 5) Supplier detail connections list: add Connection Dead column
# ---------------------------------------------------------------------------

cat > resources/views/suppliers/show.blade.php << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Supplier: {{ $supplier->name }}
        </h2>
    </x-slot>

    <div class="py-6">
        <div class="max-w-5xl mx-auto sm:px-6 lg:px-8">
            @if (session('status'))
                <div class="mb-4 text-sm text-green-600">
                    {{ session('status') }}
                </div>
            @endif

            {{-- Supplier basic info --}}
            <div class="bg-white shadow-sm rounded-lg p-6 mb-6">
                <dl class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                    <div>
                        <dt class="font-medium text-gray-500">Name</dt>
                        <dd class="text-gray-900">{{ $supplier->name }}</dd>
                    </div>
                    <div>
                        <dt class="font-medium text-gray-500">Email</dt>
                        <dd class="text-gray-900">{{ $supplier->email }}</dd>
                    </div>
                    <div class="md:col-span-2">
                        <dt class="font-medium text-gray-500">Notes</dt>
                        <dd class="text-gray-900 whitespace-pre-line">
                            {{ $supplier->notes }}
                        </dd>
                    </div>
                </dl>

                <div class="mt-4 flex justify-end space-x-2">
                    <a href="{{ route('suppliers.index') }}"
                       class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                        Back to list
                    </a>
                    <a href="{{ route('suppliers.edit', $supplier) }}"
                       class="inline-flex items-center px-3 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-indigo-600 text-white hover:bg-indigo-700">
                        Edit Supplier
                    </a>
                </div>
            </div>

            {{-- Connections list --}}
            <div class="flex items-center justify-between mb-2">
                <h3 class="text-lg font-semibold text-gray-800">
                    Connections
                </h3>
                <a href="{{ route('suppliers.connections.create', $supplier) }}"
                   class="inline-flex items-center px-3 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-indigo-600 text-white hover:bg-indigo-700">
                    + New Connection
                </a>
            </div>

            <div class="bg-white shadow-sm rounded-lg overflow-hidden">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                    <thead class="bg-gray-50">
                        <tr>
                            <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Connection Name
                            </th>
                            <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Username
                            </th>
                            <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Product Type
                            </th>
                            <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Connection Dead
                            </th>
                            <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Charge Type
                            </th>
                            <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Notes
                            </th>
                            <th scope="col" class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Actions
                            </th>
                        </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                        @forelse($supplier->connections as $connection)
                            <tr>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $connection->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $connection->username }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $connection->product_type }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    @if($connection->connection_dead)
                                        <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-red-50 text-red-700 text-xs">
                                            Dead
                                        </span>
                                    @else
                                        <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-green-50 text-green-700 text-xs">
                                            Live
                                        </span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $connection->charge_type_label ?? $connection->charge_type }}
                                </td>
                                <td class="px-4 py-2 text-sm text-gray-500 max-w-md">
                                    <div class="line-clamp-2">
                                        {{ $connection->notes }}
                                    </div>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-right text-sm">
                                    <a href="{{ route('suppliers.connections.edit', [$supplier, $connection]) }}"
                                       class="text-indigo-600 hover:text-indigo-900 mr-3">
                                        Edit
                                    </a>
                                    <form action="{{ route('suppliers.connections.destroy', [$supplier, $connection]) }}"
                                          method="POST"
                                          class="inline"
                                          onsubmit="return confirm('Delete this connection?');">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit"
                                                class="text-red-600 hover:text-red-800">
                                            Delete
                                        </button>
                                    </form>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" class="px-4 py-4 text-center text-sm text-gray-500">
                                    No connections yet for this supplier.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</x-app-layout>
BLADE
echo "==> Rewrote resources/views/suppliers/show.blade.php"

# ---------------------------------------------------------------------------
# 6) Run migrations & clear cache inside container
# ---------------------------------------------------------------------------
echo "==> Running migrations"
docker compose exec -T app php artisan migrate --force

echo "==> Clearing caches"
docker compose exec -T app php artisan optimize:clear

echo "==> add_connection_dead_field_v1: done"
