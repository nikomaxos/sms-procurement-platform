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
