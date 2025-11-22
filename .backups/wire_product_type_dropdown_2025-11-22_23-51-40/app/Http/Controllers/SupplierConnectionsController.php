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
