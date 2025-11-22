#!/usr/bin/env bash
set -euo pipefail

##
# add_suppliers_module_v1.sh
#
# Adds a basic Suppliers CRUD module:
# - Migration: suppliers table
# - Model: App\Models\Supplier
# - Controller: App\Http\Controllers\SuppliersController
# - Views: resources/views/suppliers/*
# - Routes: resource('suppliers', ...)
# - Navigation: "Suppliers" link next to "Networks"
#
# Run from repo root:
#   chmod +x scripts/add_suppliers_module_v1.sh
#   ./scripts/add_suppliers_module_v1.sh
##

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
  pwd
)"

cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/add_suppliers_${STAMP}"

echo "==> Creating backup dir at ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

backup_file() {
  local f="$1"
  if [[ -f "${f}" ]]; then
    echo "   - Backing up ${f}"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    cp "${f}" "${BACKUP_DIR}/${f}"
  fi
}

# Files we might touch
backup_file "app/Models/Supplier.php"
backup_file "app/Http/Controllers/SuppliersController.php"
backup_file "routes/web.php"
backup_file "resources/views/layouts/navigation.blade.php"
backup_file "resources/views/suppliers/index.blade.php"
backup_file "resources/views/suppliers/create.blade.php"
backup_file "resources/views/suppliers/edit.blade.php"
backup_file "database/migrations/2025_11_22_150000_create_suppliers_table.php"

echo "==> Writing migration for suppliers table"
cat > database/migrations/2025_11_22_150000_create_suppliers_table.php <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('suppliers', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('suppliers');
    }
};
PHP

echo "==> Writing App\\Models\\Supplier"
mkdir -p app/Models
cat > app/Models/Supplier.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Supplier extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'email',
        'notes',
    ];
}
PHP

echo "==> Writing App\\Http\\Controllers\\SuppliersController"
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

        Supplier::create($data);

        return redirect()
            ->route('suppliers.index')
            ->with('status', 'Supplier created.');
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
            ->route('suppliers.index')
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

echo "==> Writing suppliers views"
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
                                {{ $supplier->name }}
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
                                <a href="{{ route('suppliers.edit', $supplier) }}"
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

cat > resources/views/suppliers/create.blade.php <<'BLADE'
<x-app-layout>
    @section('content')
    <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <h1 class="text-2xl font-semibold text-gray-800 mb-4">
            New Supplier
        </h1>

        <form method="POST" action="{{ route('suppliers.store') }}" class="space-y-6">
            @csrf

            <div>
                <label for="name" class="block text-sm font-medium text-gray-700">Supplier Name</label>
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
                <label for="email" class="block text-sm font-medium text-gray-700">Email Address</label>
                <input type="email"
                       name="email"
                       id="email"
                       value="{{ old('email') }}"
                       class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                @error('email')
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
                <a href="{{ route('suppliers.index') }}"
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

cat > resources/views/suppliers/edit.blade.php <<'BLADE'
<x-app-layout>
    @section('content')
    <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <h1 class="text-2xl font-semibold text-gray-800 mb-4">
            Edit Supplier
        </h1>

        <form method="POST" action="{{ route('suppliers.update', $supplier) }}" class="space-y-6">
            @csrf
            @method('PUT')

            <div>
                <label for="name" class="block text-sm font-medium text-gray-700">Supplier Name</label>
                <input type="text"
                       name="name"
                       id="name"
                       value="{{ old('name', $supplier->name) }}"
                       required
                       class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                @error('name')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="email" class="block text-sm font-medium text-gray-700">Email Address</label>
                <input type="email"
                       name="email"
                       id="email"
                       value="{{ old('email', $supplier->email) }}"
                       class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                @error('email')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="notes" class="block text-sm font-medium text-gray-700">Notes</label>
                <textarea
                    name="notes"
                    id="notes"
                    rows="5"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">{{ old('notes', $supplier->notes) }}</textarea>
                @error('notes')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div class="flex justify-between items-center">
                <form action="{{ route('suppliers.destroy', $supplier) }}"
                      method="POST"
                      onsubmit="return confirm('Delete this supplier?');">
                    @csrf
                    @method('DELETE')
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-red-500 text-sm font-medium rounded-md text-red-700 bg-white hover:bg-red-50">
                        Delete
                    </button>
                </form>

                <div class="flex space-x-3">
                    <a href="{{ route('suppliers.index') }}"
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

echo "==> Appending suppliers routes (auth-protected)"
if ! grep -q "SuppliersController" routes/web.php; then
  cat >> routes/web.php <<'PHP'

/*
|--------------------------------------------------------------------------
| Suppliers
|--------------------------------------------------------------------------
*/

use App\Http\Controllers\SuppliersController;

Route::middleware(['auth'])->group(function () {
    Route::resource('suppliers', SuppliersController::class)->except(['show']);
});
PHP
else
  echo "    (routes/web.php already references SuppliersController; skipping append)"
fi

echo "==> Attempting to inject 'Suppliers' into navigation next to 'Networks' (desktop)"
if [[ -f "resources/views/layouts/navigation.blade.php" ]]; then
  perl -0pi -e '
    s#(
        <x-nav-link\s+href="{{\s*route\('\''networks.index'\''\)\s*}}".*?
        </x-nav-link>
    )#$1\n            <x-nav-link href="{{ route('\''suppliers.index'\'') }}" :active="request()->routeIs('\''suppliers.*'\'')">\n                {{ __( '\''Suppliers'\'' ) }}\n            </x-nav-link>#gsx
  ' resources/views/layouts/navigation.blade.php || true

  echo "==> Attempting to inject 'Suppliers' into responsive/mobile navigation"
  perl -0pi -e '
    s#(
        <x-responsive-nav-link\s+href="{{\s*route\('\''networks.index'\''\)\s*}}".*?
        </x-responsive-nav-link>
    )#$1\n            <x-responsive-nav-link href="{{ route('\''suppliers.index'\'') }}" :active="request()->routeIs('\''suppliers.*'\'')">\n                {{ __( '\''Suppliers'\'' ) }}\n            </x-responsive-nav-link>#gsx
  ' resources/views/layouts/navigation.blade.php || true
else
  echo "    (navigation.blade.php not found; please add the Suppliers link manually)"
fi

echo "==> Running migrations inside Docker (service: app)"
docker compose exec -T app php artisan migrate

echo "==> Done. Suppliers module added."
echo "    Backup of any overwritten files is in: ${BACKUP_DIR}"
