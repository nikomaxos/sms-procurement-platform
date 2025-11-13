<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Network;
use App\Models\Country;

class NetworksController extends Controller {
    public function __construct(){ $this->middleware('auth'); }

    public function index(Request $r){
        $per = (int) $r->input('per', 20);
        if (!in_array($per, [20,50,100,1000])) $per = 20;

        $q        = trim((string) $r->input('q',''));
        $mcc      = trim((string) $r->input('mcc',''));
        $mnc      = trim((string) $r->input('mnc',''));
        $mcc_mnc  = trim((string) $r->input('mcc_mnc',''));
        $countryQ = trim((string) $r->input('country',''));

        $networks = Network::query()
            ->leftJoin('countries','countries.id','=','networks.country_id')
            ->select('networks.*','countries.name as country_name')
            ->when($q !== '', function($qq) use ($q){
                $qq->where(function($w) use ($q){
                    $w->where('networks.name','ilike',"%{$q}%")
                      ->orWhere('networks.mcc','ilike',"%{$q}%")
                      ->orWhere('networks.mnc','ilike',"%{$q}%")
                      ->orWhere('networks.mcc_mnc','ilike',"%{$q}%")
                      ->orWhere('countries.name','ilike',"%{$q}%");
                });
            })
            ->when($mcc !== '',     fn($qq)=>$qq->where('networks.mcc',$mcc))
            ->when($mnc !== '',     fn($qq)=>$qq->where('networks.mnc',$mnc))
            ->when($mcc_mnc !== '', fn($qq)=>$qq->where('networks.mcc_mnc','ilike',"%{$mcc_mnc}%"))
            ->when($countryQ !== '',fn($qq)=>$qq->where('countries.name','ilike',"%{$countryQ}%"))
            ->orderBy('country_name')
            ->orderBy('networks.mcc_mnc')
            ->paginate($per)
            ->appends($r->all());

        // keep relation available in views
        $networks->getCollection()->load('country');

        return view('networks.index', compact('networks'));
    }

    public function create(){
        $network   = new Network();
        $countries = Country::orderBy('name')->get(['id','name']);
        return view('networks.create', compact('network','countries'));
    }

    public function store(Request $r){
        $data = $r->validate([
            'country_id' => 'required|exists:countries,id',
            'name'       => 'required|string|max:255',
            'mcc'        => 'required|string|max:3',
            'mnc'        => 'required|string|max:3',
        ]);
        $data['mcc_mnc'] = ($data['mcc'] ?? '').($data['mnc'] ?? '');
        $network = Network::create($data);
        return redirect()->route('networks.edit',$network)->with('status','Network created');
    }

    public function edit(Network $network){
        $countries = Country::orderBy('name')->get(['id','name']);
        return view('networks.edit', compact('network','countries'));
    }

    public function update(Request $r, Network $network){
        $data = $r->validate([
            'country_id' => 'required|exists:countries,id',
            'name'       => 'required|string|max:255',
            'mcc'        => 'required|string|max:3',
            'mnc'        => 'required|string|max:3',
        ]);
        $data['mcc_mnc'] = ($data['mcc'] ?? '').($data['mnc'] ?? '');
        $network->update($data);
        return back()->with('status','Network updated');
    }

    public function destroy(Network $network){
        $network->delete();
        return redirect()->route('networks.index')->with('status','Deleted');
    }
}
