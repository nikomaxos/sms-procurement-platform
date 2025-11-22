#!/usr/bin/env bash
set -euo pipefail

##
# add_products_provided_to_suppliers_list_v1.sh
#
# - Updates SuppliersController@index to eager-load `connections`
# - Rewrites suppliers index view to show "Products Provided"
#   as chips from distinct connection.product_type values
##

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/add_products_provided_to_suppliers_list_${STAMP}"
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

backup_file "app/Http/Controllers/SuppliersController.php"
backup_file "resources/views/suppliers/index.blade.php"

# ---------------------------------------------------------------------------
# 1) Rewrite SuppliersController with eager-loaded connections
# ---------------------------------------------------------------------------
cat > app/Http/Controllers/SuppliersController.php << 'PHP'
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

        // Eager-load connections so we can aggregate product_type per supplier
        $query = Supplier::with('connections');

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
echo "==> Rewrote app/Http/Controllers/SuppliersController.php"

# ---------------------------------------------------------------------------
# 2) Rewrite suppliers index view with 'Products Provided' column
# ---------------------------------------------------------------------------
cat > resources/views/suppliers/index.blade.php << 'BLADE'
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
                            Products Provided
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
                        @php
                            $productTypes = $supplier->connections
                                ->pluck('product_type')
                                ->filter()
                                ->unique()
                                ->values();
                        @endphp
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
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                @forelse($productTypes as $type)
                                    <span class="inline-flex items-center px-2 py-0.5 rounded-full border border-blue-200 bg-blue-50 text-blue-700 text-xs mr-1">
                                        {{ $type }}
                                    </span>
                                @empty
                                    <span class="text-gray-400 text-xs">—</span>
                                @endforelse
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
                            <td colspan="5" class="px-4 py-4 text-center text-sm text-gray-500">
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
echo "==> Rewrote resources/views/suppliers/index.blade.php"

echo "==> Optional: php -l and view:clear inside container"
if command -v docker >/dev/null 2>&1; then
  docker compose exec -T app bash -lc '
    cd /var/www/html && \
    php -l app/Http/Controllers/SuppliersController.php && \
    php artisan view:clear
  ' || echo "   (php -l or view:clear reported an issue or container not running; inspect manually if needed)"
fi

echo "==> Done. Suppliers list now shows Products Provided chips."
