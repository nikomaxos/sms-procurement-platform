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
