<?php

namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\DropdownMenu;
use Illuminate\Http\Request;

class DropdownMenuController extends Controller
{
    protected $modules = [
        'supplier_offers' => 'Supplier Offers',
        'countries' => 'Countries',
        'networks' => 'Networks',
        'suppliers' => 'Suppliers',
        'supplier_connections' => 'Supplier Connections',
    ];

    public function __construct()
    {
        $this->middleware('auth');
    }

    public function index()
    {
        $menus = DropdownMenu::query()->withCount('items')->orderBy('id', 'desc')->paginate(20);
        return view('settings.dropdowns.index', compact('menus'));
    }

    public function create()
    {
        $modules = $this->modules;
        return view('settings.dropdowns.create', compact('modules'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:120'],
            'module' => ['nullable', 'string', 'max:120'],
        ]);
        $menu = DropdownMenu::create($data);
        return redirect()->route('settings.dropdowns.items.index', $menu)->with('status', 'menu-created');
    }

    public function edit(DropdownMenu $menu)
    {
        $modules = $this->modules;
        return view('settings.dropdowns.edit', compact('menu', 'modules'));
    }

    public function update(Request $request, DropdownMenu $menu)
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:120'],
            'module' => ['nullable', 'string', 'max:120'],
        ]);
        $menu->update($data);
        return redirect()->route('settings.dropdowns.index')->with('status', 'menu-updated');
    }

    public function destroy(DropdownMenu $menu)
    {
        $menu->delete();
        return redirect()->route('settings.dropdowns.index')->with('status', 'menu-deleted');
    }
}
