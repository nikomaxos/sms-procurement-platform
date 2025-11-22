#!/usr/bin/env bash
set -euo pipefail

##
# add_supplier_connections_v1.sh
#
# Adds "Connections" as a sub-object of Supplier (1:N):
# - Migration: supplier_connections table
# - Model: App\Models\SupplierConnection
# - Relation: Supplier::connections()
# - Controller: SuppliersController updated with show()
# - Controller: SupplierConnectionsController for nested CRUD
# - Views:
#     - suppliers/show.blade.php
#     - suppliers/connections/create.blade.php
#     - suppliers/connections/edit.blade.php
# - Routes:
#     - /suppliers/{supplier} (show)
#     - /suppliers/{supplier}/connections/... (create/store/edit/update/destroy)
#
# Run from repo root:
#   chmod +x scripts/add_supplier_connections_v1.sh
#   ./scripts/add_supplier_connections_v1.sh
##

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
  pwd
)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/add_supplier_connections_${STAMP}"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

backup_file() {
  local f="$1"
  if [[ -f "${f}" ]]; then
    echo "   - Backing up ${f}"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    cp "${f}" "${BACKUP_DIR}/${f}"
  fi
}

# Files we may touch
backup_file "app/Models/Supplier.php"
backup_file "app/Models/SupplierConnection.php"
backup_file "app/Http/Controllers/SuppliersController.php"
backup_file "app/Http/Controllers/SupplierConnectionsController.php"
backup_file "routes/web.php"
backup_file "resources/views/suppliers/index.blade.php"
backup_file "resources/views/suppliers/show.blade.php"
backup_file "resources/views/suppliers/connections/create.blade.php"
backup_file "resources/views/suppliers/connections/edit.blade.php"
backup_file "database/migrations/2025_11_22_160000_create_supplier_connections_table.php"

echo "==> Writing migration: supplier_connections table"
mkdir -p database/migrations
cat > database/migrations/2025_11_22_160000_create_supplier_connections_table.php <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('supplier_connections', function (Blueprint $table) {
            $table->id();
            $table->foreignId('supplier_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('username')->nullable();
            $table->string('charge_type', 32);
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index('supplier_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_connections');
    }
};
PHP

echo "==> Writing App\\Models\\SupplierConnection model"
mkdir -p app/Models
cat > app/Models/SupplierConnection.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SupplierConnection extends Model
{
    use HasFactory;

    public const CHARGE_TYPE_PER_SUBMIT = 'per_submit';
    public const CHARGE_TYPE_PER_DELIVERED = 'per_delivered';

    public const CHARGE_TYPE_OPTIONS = [
        self::CHARGE_TYPE_PER_SUBMIT => 'Per Submit',
        self::CHARGE_TYPE_PER_DELIVERED => 'Per Delivered',
    ];

    protected $fillable = [
        'supplier_id',
        'name',
        'username',
        'charge_type',
        'notes',
    ];

    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }

    public function getChargeTypeLabelAttribute(): string
    {
        return self::CHARGE_TYPE_OPTIONS[$this->charge_type] ?? $this->charge_type;
    }
}
PHP

echo "==> Ensuring Supplier::connections() relation exists"
if grep -q "function connections(" app/Models/Supplier.php 2>/dev/null; then
  echo "   - Supplier::connections() already present; skipping relation patch."
else
  perl -0pi -e '
    s#}\s*$#    public function connections()\n    {\n        return $this->hasMany(\\App\\Models\\SupplierConnection::class);\n    }\n}\n#' app/Models/Supplier.php
fi

echo "==> Rewriting SuppliersController with show() detail and redirects"
mkdir -p app/Http/Controllers
cat > app/Http/Controllers/SuppliersController.php <<'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\Supplier;
use Illuminate\Http\Request;

class SuppliersController extends Controller
{
    public function index(Request $request)
    {
        $perPage = (int) $request->input('per_page', 50);
        $perPage = max(10, min($perPage, 200));

        $q = trim((string) $request->input('q', ''));

        $query = Supplier::query();

        if ($q !== '') {
            $needle = mb_strtolower($q);
            $query->where(function ($q) use ($needle) {
                $q->whereRaw('LOWER(name) LIKE ?', ['%' . $needle . '%'])
                  ->orWhereRaw('LOWER(email) LIKE ?', ['%' . $needle . '%']);
            });
        }

        $suppliers = $query
            ->orderBy('name')
            ->paginate($perPage)
            ->withQueryString();

        return view('suppliers.index', [
            'suppliers' => $suppliers,
            'q'         => $q,
            'perPage'   => $perPage,
        ]);
    }

    public function create()
    {
        return view('suppliers.create');
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name'  => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'string', 'email', 'max:255'],
            'notes' => ['nullable', 'string'],
        ]);

        $supplier = Supplier::create($data);

        return redirect()
            ->route('suppliers.show', $supplier)
            ->with('status', 'Supplier created.');
    }

    public function show(Supplier $supplier)
    {
        $supplier->load(['connections' => function ($q) {
            $q->orderBy('name');
        }]);

        return view('suppliers.show', [
            'supplier' => $supplier,
        ]);
    }

    public function edit(Supplier $supplier)
    {
        return view('suppliers.edit', [
            'supplier' => $supplier,
        ]);
    }

    public function update(Request $request, Supplier $supplier)
    {
        $data = $request->validate([
            'name'  => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'string', 'email', 'max:255'],
            'notes' => ['nullable', 'string'],
        ]);

        $supplier->update($data);

        return redirect()
            ->route('suppliers.show', $supplier)
            ->with('status', 'Supplier updated.');
    }

    public function destroy(Supplier $supplier)
    {
        $supplier->delete();

        return redirect()
            ->route('suppliers.index')
            ->with('status', 'Supplier deleted.');
    }
}
PHP

echo "==> Writing SupplierConnectionsController (nested under Supplier)"
cat > app/Http/Controllers/SupplierConnectionsController.php <<'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\Supplier;
use App\Models\SupplierConnection;
use Illuminate\Http\Request;

class SupplierConnectionsController extends Controller
{
    protected function validateData(Request $request): array
    {
        return $request->validate([
            'name'        => ['required', 'string', 'max:255'],
            'username'    => ['nullable', 'string', 'max:255'],
            'charge_type' => [
                'required',
                'string',
                'in:' . implode(',', array_keys(SupplierConnection::CHARGE_TYPE_OPTIONS)),
            ],
            'notes'       => ['nullable', 'string'],
        ]);
    }

    public function create(Supplier $supplier)
    {
        return view('suppliers.connections.create', [
            'supplier' => $supplier,
        ]);
    }

    public function store(Request $request, Supplier $supplier)
    {
        $data = $this->validateData($request);

        $supplier->connections()->create($data);

        return redirect()
            ->route('suppliers.show', $supplier)
            ->with('status', 'Connection created.');
    }

    public function edit(Supplier $supplier, SupplierConnection $connection)
    {
        if ($connection->supplier_id !== $supplier->id) {
            abort(404);
        }

        return view('suppliers.connections.edit', [
            'supplier'   => $supplier,
            'connection' => $connection,
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
}
PHP

echo "==> Updating suppliers index view (name + Edit go to detail page)"
mkdir -p resources/views/suppliers
cat > resources/views/suppliers/index.blade.php <<'BLADE'
<x-app-layout>
    @section('content')
    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between mb-4">
            <h1 class="text-2xl font-semibold text-gray-800">
                Suppliers
            </h1>
            <a href="{{ route('suppliers.create') }}"
               class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                + New Supplier
            </a>
        </div>

        <form method="GET" action="{{ route('suppliers.index') }}" class="mb-4">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-3 items-end">
                <div>
                    <label for="q" class="block text-sm font-medium text-gray-700">Search</label>
                    <input type="text"
                           name="q"
                           id="q"
                           value="{{ old('q', $q) }}"
                           class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                           placeholder="Name or email">
                </div>

                <div>
                    <label for="per_page" class="block text-sm font-medium text-gray-700">Results per page</label>
                    <select name="per_page" id="per_page"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                        @foreach([25,50,100,200] as $option)
                            <option value="{{ $option }}" @selected($perPage == $option)>{{ $option }}</option>
                        @endforeach
                    </select>
                </div>

                <div class="flex space-x-2 md:justify-end">
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                        Apply filters
                    </button>
                    <a href="{{ route('suppliers.index') }}"
                       class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                        Reset
                    </a>
                </div>
            </div>
        </form>

        <div class="bg-white shadow-sm rounded-lg overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50">
                    <tr>
                        <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Name
                        </th>
                        <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Email
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
                    @forelse($suppliers as $supplier)
                        <tr>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                <a href="{{ route('suppliers.show', $supplier) }}"
                                   class="text-blue-600 hover:text-blue-900">
                                    {{ $supplier->name }}
                                </a>
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                {{ $supplier->email }}
                            </td>
                            <td class="px-4 py-2 text-sm text-gray-500 max-w-md">
                                <div class="line-clamp-2">
                                    {{ $supplier->notes }}
                                </div>
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-right text-sm">
                                <a href="{{ route('suppliers.show', $supplier) }}"
                                   class="text-blue-600 hover:text-blue-900 mr-3">
                                    Edit
                                </a>
                                <form action="{{ route('suppliers.destroy', $supplier) }}"
                                      method="POST"
                                      class="inline"
                                      onsubmit="return confirm('Delete this supplier?');">
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
                            <td colspan="4" class="px-4 py-4 text-center text-sm text-gray-500">
                                No suppliers found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div class="mt-4">
            {{ $suppliers->links() }}
        </div>
    </div>
    @endsection
</x-app-layout>
BLADE

echo "==> Writing supplier detail view with Connections list"
cat > resources/views/suppliers/show.blade.php <<'BLADE'
<x-app-layout>
    @section('content')
    <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        @if (session('status'))
            <div class="mb-4 text-sm text-green-600">
                {{ session('status') }}
            </div>
        @endif

        <div class="flex items-center justify-between mb-4">
            <h1 class="text-2xl font-semibold text-gray-800">
                Supplier: {{ $supplier->name }}
            </h1>
            <div class="flex space-x-2">
                <a href="{{ route('suppliers.index') }}"
                   class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                    Back to list
                </a>
                <a href="{{ route('suppliers.edit', $supplier) }}"
                   class="inline-flex items-center px-3 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                    Edit Supplier
                </a>
            </div>
        </div>

        <div class="bg-white shadow-sm rounded-lg p-4 mb-6">
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
        </div>

        <div class="flex items-center justify-between mb-2">
            <h2 class="text-xl font-semibold text-gray-800">
                Connections
            </h2>
            <a href="{{ route('suppliers.connections.create', $supplier) }}"
               class="inline-flex items-center px-3 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
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
                                {{ $connection->charge_type_label }}
                            </td>
                            <td class="px-4 py-2 text-sm text-gray-500 max-w-md">
                                <div class="line-clamp-2">
                                    {{ $connection->notes }}
                                </div>
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-right text-sm">
                                <a href="{{ route('suppliers.connections.edit', [$supplier, $connection]) }}"
                                   class="text-blue-600 hover:text-blue-900 mr-3">
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
                            <td colspan="5" class="px-4 py-4 text-center text-sm text-gray-500">
                                No connections yet for this supplier.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @endsection
</x-app-layout>
BLADE

echo "==> Writing connection create/edit views"
mkdir -p resources/views/suppliers/connections

cat > resources/views/suppliers/connections/create.blade.php <<'BLADE'
<x-app-layout>
    @section('content')
    <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <h1 class="text-2xl font-semibold text-gray-800 mb-4">
            New Connection for {{ $supplier->name }}
        </h1>

        @php
            $chargeOptions = \App\Models\SupplierConnection::CHARGE_TYPE_OPTIONS;
        @endphp

        <form method="POST" action="{{ route('suppliers.connections.store', $supplier) }}" class="space-y-6">
            @csrf

            <div>
                <label for="name" class="block text-sm font-medium text-gray-700">Connection Name</label>
                <input type="text"
                       name="name"
                       id="name"
                       value="{{ old('name') }}"
                       required
                       class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                @error('name')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="username" class="block text-sm font-medium text-gray-700">Username</label>
                <input type="text"
                       name="username"
                       id="username"
                       value="{{ old('username') }}"
                       class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                @error('username')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="charge_type" class="block text-sm font-medium text-gray-700">Charge Type</label>
                <select
                    name="charge_type"
                    id="charge_type"
                    required
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                    <option value="">-- Select --</option>
                    @foreach($chargeOptions as $value => $label)
                        <option value="{{ $value }}" @selected(old('charge_type') === $value)>
                            {{ $label }}
                        </option>
                    @endforeach
                </select>
                @error('charge_type')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="notes" class="block text-sm font-medium text-gray-700">Notes</label>
                <textarea
                    name="notes"
                    id="notes"
                    rows="5"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">{{ old('notes') }}</textarea>
                @error('notes')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div class="flex justify-end space-x-3">
                <a href="{{ route('suppliers.show', $supplier) }}"
                   class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                    Cancel
                </a>
                <button type="submit"
                        class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                    Save
                </button>
            </div>
        </form>
    </div>
    @endsection
</x-app-layout>
BLADE

cat > resources/views/suppliers/connections/edit.blade.php <<'BLADE'
<x-app-layout>
    @section('content')
    <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <h1 class="text-2xl font-semibold text-gray-800 mb-4">
            Edit Connection for {{ $supplier->name }}
        </h1>

        @php
            $chargeOptions = \App\Models\SupplierConnection::CHARGE_TYPE_OPTIONS;
        @endphp

        <form method="POST" action="{{ route('suppliers.connections.update', [$supplier, $connection]) }}" class="space-y-6">
            @csrf
            @method('PUT')

            <div>
                <label for="name" class="block text-sm font-medium text-gray-700">Connection Name</label>
                <input type="text"
                       name="name"
                       id="name"
                       value="{{ old('name', $connection->name) }}"
                       required
                       class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                @error('name')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="username" class="block text-sm font-medium text-gray-700">Username</label>
                <input type="text"
                       name="username"
                       id="username"
                       value="{{ old('username', $connection->username) }}"
                       class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                @error('username')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="charge_type" class="block text-sm font-medium text-gray-700">Charge Type</label>
                <select
                    name="charge_type"
                    id="charge_type"
                    required
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                    <option value="">-- Select --</option>
                    @foreach($chargeOptions as $value => $label)
                        <option value="{{ $value }}" @selected(old('charge_type', $connection->charge_type) === $value)>
                            {{ $label }}
                        </option>
                    @endforeach
                </select>
                @error('charge_type')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="notes" class="block text-sm font-medium text-gray-700">Notes</label>
                <textarea
                    name="notes"
                    id="notes"
                    rows="5"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">{{ old('notes', $connection->notes) }}</textarea>
                @error('notes')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div class="flex justify-between items-center">
                <form action="{{ route('suppliers.connections.destroy', [$supplier, $connection]) }}"
                      method="POST"
                      onsubmit="return confirm('Delete this connection?');">
                    @csrf
                    @method('DELETE')
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-red-500 text-sm font-medium rounded-md text-red-700 bg-white hover:bg-red-50">
                        Delete
                    </button>
                </form>

                <div class="flex space-x-3">
                    <a href="{{ route('suppliers.show', $supplier) }}"
                       class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                        Cancel
                    </a>
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                        Save changes
                    </button>
                </div>
            </div>
        </form>
    </div>
    @endsection
</x-app-layout>
BLADE

echo "==> Updating routes for suppliers + nested connections"
# Ensure SupplierConnectionsController use statement
if ! grep -q "SupplierConnectionsController" routes/web.php 2>/dev/null; then
  perl -0pi -e '
    s/use App\\\Http\\\Controllers\\\SuppliersController;/use App\\\Http\\\Controllers\\\SuppliersController;\nuse App\\\Http\\\Controllers\\\SupplierConnectionsController;/' routes/web.php || true
fi

# Allow suppliers.show by removing ->except(['show']) if present
if grep -q "Route::resource('suppliers', SuppliersController::class)->except(['show']);" routes/web.php 2>/dev/null; then
  perl -0pi -e "
    s/Route::resource\('suppliers', SuppliersController::class\)->except\(\['show'\]\);/Route::resource('suppliers', SuppliersController::class);/" routes/web.php
fi

# Append nested connections routes if not already present
if ! grep -q "suppliers.connections.create" routes/web.php 2>/dev/null; then
  cat >> routes/web.php <<'PHP'

Route::middleware(['auth'])->group(function () {
    Route::prefix('suppliers/{supplier}')->name('suppliers.')->group(function () {
        Route::get('connections/create', [SupplierConnectionsController::class, 'create'])->name('connections.create');
        Route::post('connections', [SupplierConnectionsController::class, 'store'])->name('connections.store');
        Route::get('connections/{connection}/edit', [SupplierConnectionsController::class, 'edit'])->name('connections.edit');
        Route::put('connections/{connection}', [SupplierConnectionsController::class, 'update'])->name('connections.update');
        Route::delete('connections/{connection}', [SupplierConnectionsController::class, 'destroy'])->name('connections.destroy');
    });
}
PHP
fi

echo "==> Running migrations inside Docker (service: app)"
docker compose exec -T app php artisan migrate

echo "==> Done. Supplier Connections feature added."
echo "    Backups saved under: ${BACKUP_DIR}"
