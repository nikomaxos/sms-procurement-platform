<?php
namespace App\Http\Controllers\Admin;
use App\Http\Controllers\Controller;
use App\Models\KnownHop;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class KnownHopController extends Controller
{
    public function __construct(){ $this->middleware(['auth','can:admin']); }
    public function index(){ $items=KnownHop::orderBy('name')->paginate(20); return view('admin.known_hops.index', compact('items')); }
    public function create(){ return view('admin.known_hops.create'); }
    public function store(Request $request){
        $data = $request->validate(['name'=>'required|string|max:100']);
        $slug = Str::slug($data['name']);
        KnownHop::create(['name'=>$data['name'],'slug'=>$slug]);
        return redirect()->route('admin.known_hops.index')->with('status','Saved');
    }
    public function edit(KnownHop $item){ return view('admin.known_hops.edit', compact('item')); }
    public function update(Request $request, KnownHop $item){
        $data = $request->validate(['name'=>'required|string|max:100']);
        $item->update(['name'=>$data['name'], 'slug'=>Str::slug($data['name'])]);
        return redirect()->route('admin.known_hops.index')->with('status','Updated');
    }
    public function destroy(KnownHop $item){ $item->delete(); return redirect()->route('admin.known_hops.index')->with('status','Deleted'); }
}
