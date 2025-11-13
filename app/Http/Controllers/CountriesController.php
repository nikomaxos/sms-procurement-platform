<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Country;
use App\Models\CountryMcc;

class CountriesController extends Controller {
    public function __construct(){ $this->middleware('auth'); }

    public function index(Request $r){
        $per = (int) $r->input('per', 20);
        if (!in_array($per, [20,50,100,1000])) $per = 20;
        $q   = trim((string) $r->input('q',''));
        $mcc = trim((string) $r->input('mcc',''));

        $countries = Country::with('mccs')
            ->when($q !== '', function($qq) use ($q){
                $qq->where('name','ilike',"%{$q}%")
                   ->orWhere('iso2','ilike',"%{$q}%");
            })
            ->when($mcc !== '', function($qq) use ($mcc){
                $qq->whereHas('mccs', function($w) use ($mcc){
                    $w->where('mcc', $mcc);
                });
            })
            ->orderBy('name')
            ->paginate($per)
            ->appends($r->all());

        return view('countries.index', compact('countries'));
    }

    public function create(){
        $country = new Country();
        return view('countries.create', compact('country'));
    }

    public function store(Request $r){
        $data = $r->validate([
            'name' => 'required|string|max:255',
            'iso2' => 'nullable|string|max:2'
        ]);
        $country = Country::create($data);
        return redirect()->route('countries.edit', $country)
            ->with('status','Country created');
    }

    public function edit(Country $country){
        $country->load('mccs');
        return view('countries.edit', compact('country'));
    }

    public function update(Request $r, Country $country){
        $data = $r->validate([
            'name' => 'required|string|max:255',
            'iso2' => 'nullable|string|max:2'
        ]);
        $country->update($data);
        return back()->with('status','Country updated');
    }

    public function destroy(Country $country){
        $country->delete();
        return redirect()->route('countries.index')->with('status','Deleted');
    }

    // typeahead JSON
    public function lookup(Request $r){
        $q = trim((string) $r->query('q',''));
        $rows = Country::when($q !== '', function($qq) use ($q){
                    $qq->where('name','ilike',"%{$q}%");
                })
                ->orderBy('name')
                ->limit(8)
                ->get(['id','name']);
        return response()->json($rows);
    }
}
