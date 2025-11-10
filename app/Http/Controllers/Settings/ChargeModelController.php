<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\ChargeModel;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ChargeModelController extends Controller
{
    public function index() {
        return view('settings.dropdowns.index', [
            'routeTypes'   => \App\Models\RouteType::orderBy('name')->get(),
            'knownHops'    => \App\Models\KnownHop::orderBy('name')->get(),
            'chargeModels' => \App\Models\ChargeModel::orderBy('name')->get(),
        ]);
    }
    public function store(Request $request) {
        $data = $request->validate(['name'=>['required','string','max:100','unique:charge_models,name']]);
        ChargeModel::create($data);
        return back()->with('status','Saved.');
    }
    public function update(Request $request, ChargeModel $item) {
        $data = $request->validate(['name'=>['required','string','max:100', Rule::unique('charge_models','name')->ignore($item->id)]]);
        $item->update($data);
        return back()->with('status','Updated.');
    }
    public function destroy(ChargeModel $item) {
        $item->delete();
        return back()->with('status','Deleted.');
    }
}
