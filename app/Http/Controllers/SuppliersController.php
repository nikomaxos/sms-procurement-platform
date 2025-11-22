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
