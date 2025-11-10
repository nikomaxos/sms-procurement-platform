<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\KnownHop;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class KnownHopController extends Controller
{
    public function index() {
        return view('settings.dropdowns.index', [
            'routeTypes'   => \App\Models\RouteType::orderBy('name')->get(),
            'knownHops'    => \App\Models\KnownHop::orderBy('name')->get(),
            'chargeModels' => \App\Models\ChargeModel::orderBy('name')->get(),
        ]);
    }
    public function store(Request $request) {
        $data = $request->validate(['name'=>['required','string','max:100','unique:known_hops,name']]);
        KnownHop::create($data);
        return back()->with('status','Saved.');
    }
    public function update(Request $request, KnownHop $item) {
        $data = $request->validate(['name'=>['required','string','max:100', Rule::unique('known_hops','name')->ignore($item->id)]]);
        $item->update($data);
        return back()->with('status','Updated.');
    }
    public function destroy(KnownHop $item) {
        $item->delete();
        return back()->with('status','Deleted.');
    }
}
