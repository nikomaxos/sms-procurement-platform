<?php
namespace App\Http\Controllers\Admin;
use App\Http\Controllers\Controller;
use App\Models\RouteType;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class RouteTypeController extends Controller
{
    public function __construct(){ $this->middleware(['auth','can:admin']); }
    public function index(){ $items=RouteType::orderBy('name')->paginate(20); return view('admin.route_types.index', compact('items')); }
    public function create(){ return view('admin.route_types.create'); }
    public function store(Request $request){
        $data = $request->validate(['name'=>'required|string|max:100']);
        $slug = Str::slug($data['name']);
        RouteType::create(['name'=>$data['name'],'slug'=>$slug]);
        return redirect()->route('admin.route_types.index')->with('status','Saved');
    }
    public function edit(RouteType $item){ return view('admin.route_types.edit', compact('item')); }
    public function update(Request $request, RouteType $item){
        $data = $request->validate(['name'=>'required|string|max:100']);
        $item->update(['name'=>$data['name'], 'slug'=>Str::slug($data['name'])]);
        return redirect()->route('admin.route_types.index')->with('status','Updated');
    }
    public function destroy(RouteType $item){ $item->delete(); return redirect()->route('admin.route_types.index')->with('status','Deleted'); }
}
