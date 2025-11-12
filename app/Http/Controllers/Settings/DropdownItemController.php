<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\DropdownMenu;
use App\Models\DropdownItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class DropdownItemController extends Controller {

    public function __construct(){
        $this->middleware('auth');
    }

    public function index(DropdownMenu $menu){
        $items = DropdownItem::where('dropdown_menu_id',$menu->id)
            ->orderBy('position')->orderBy('id')
            ->get();
        return view('settings.dropdowns.items.index', compact('menu','items'));
    }

    public function store(Request $request, DropdownMenu $menu){
        $data = $request->validate([
            'label' => ['required','string','max:255'],
        ]);
        $max = DropdownItem::where('dropdown_menu_id',$menu->id)->max('position') ?? 0;
        DropdownItem::create([
            'dropdown_menu_id' => $menu->id,
            'label' => $data['label'],
            'position' => $max + 1,
        ]);
        return back()->with('status','Item created');
    }

    public function edit(DropdownMenu $menu, DropdownItem $item){
        abort_unless($item->dropdown_menu_id === $menu->id, 404);
        return view('settings.dropdowns.items.edit', compact('menu','item'));
    }

    public function update(Request $request, DropdownMenu $menu, DropdownItem $item){
        abort_unless($item->dropdown_menu_id === $menu->id, 404);
        $data = $request->validate([
            'label' => ['required','string','max:255'],
        ]);
        $item->update(['label'=>$data['label']]);
        return redirect()->route('settings.dropdowns.items.index', $menu)->with('status','Item updated');
    }

    public function destroy(DropdownMenu $menu, DropdownItem $item){
        abort_unless($item->dropdown_menu_id === $menu->id, 404);
        $item->delete();
        return back()->with('status','Item deleted');
    }

    public function reorder(Request $request, DropdownMenu $menu){
        $data = $request->validate([
            'order' => ['required','array','min:1'],
            'order.*' => ['integer','distinct']
        ]);

        $ids = $data['order'];
        // verify all ids belong to the menu
        $count = DropdownItem::where('dropdown_menu_id',$menu->id)->whereIn('id',$ids)->count();
        if ($count !== count($ids)) {
            return response()->json(['ok'=>false,'message'=>'Invalid items set'], 422);
        }

        DB::transaction(function() use ($ids, $menu) {
            $pos = 0;
            foreach ($ids as $id) {
                $pos++;
                DropdownItem::where('id',$id)
                    ->where('dropdown_menu_id',$menu->id)
                    ->update(['position'=>$pos]);
            }
        });

        return response()->json(['ok'=>true]);
    }
}
