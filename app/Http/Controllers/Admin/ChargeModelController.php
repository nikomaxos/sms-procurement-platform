<?php
namespace App\Http\Controllers\Admin;
use App\Http\Controllers\Controller;
use App\Models\ChargeModel;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class ChargeModelController extends Controller
{
    public function __construct(){ $this->middleware(['auth','can:admin']); }
    public function index(){ $items=ChargeModel::orderBy('name')->paginate(20); return view('admin.charge_models.index', compact('items')); }
    public function create(){ return view('admin.charge_models.create'); }
    public function store(Request $request){
        $data = $request->validate(['name'=>'required|string|max:100']);
        $slug = Str::slug($data['name']);
        ChargeModel::create(['name'=>$data['name'],'slug'=>$slug]);
        return redirect()->route('admin.charge_models.index')->with('status','Saved');
    }
    public function edit(ChargeModel $item){ return view('admin.charge_models.edit', compact('item')); }
    public function update(Request $request, ChargeModel $item){
        $data = $request->validate(['name'=>'required|string|max:100']);
        $item->update(['name'=>$data['name'], 'slug'=>Str::slug($data['name'])]);
        return redirect()->route('admin.charge_models.index')->with('status','Updated');
    }
    public function destroy(ChargeModel $item){ $item->delete(); return redirect()->route('admin.charge_models.index')->with('status','Deleted'); }
}
