<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Network;
use App\Models\NetworkMnc;

class NetworksController extends Controller
{
    public function index(Request $r)
    {
        $per = (int) $r->input('per', 20);
        if (!in_array($per,[20,50,100,1000])) $per = 20;

        $q = Network::query()->with(['country','mncs'=>fn($qq)=>$qq->orderBy('mnc')]);

        if ($r->filled('q'))       $q->where('name','ilike','%'.$r->q.'%');
        if ($r->filled('country')) $q->whereHas('country', fn($c)=>$c->where('name','ilike','%'.$r->country.'%'));
        if ($r->filled('mcc'))     $q->whereHas('mncs', fn($m)=>$m->where('mcc',$r->mcc));
        if ($r->filled('mnc'))     $q->whereHas('mncs', fn($m)=>$m->where('mnc',$r->mnc));
        if ($r->filled('mcc_mnc')) $q->whereHas('mncs', fn($m)=>$m->where('mcc_mnc','ilike','%'.$r->mcc_mnc.'%'));

        $networks = $q->orderBy('name','asc')->paginate($per)->appends($r->all());
        return view('networks.index', compact('networks'));
    }

    public function create()
    {
        $network = new Network();
        return view('networks.create', compact('network'));
    }

    public function edit(Network $network)
    {
        $network->load(['mncs','country.mccs']);
        $primaryMcc = $network->mncs->pluck('mcc')->filter()->first()
            ?? optional($network->country?->mccs->first())->mcc
            ?? '';
        return view('networks.edit', compact('network','primaryMcc'));
    }

    public function store(Request $r)
    {
        $data = $r->validate([
            'name'=>'required|string',
            'country_id'=>'required|integer'
        ]);
        $n = new Network($data);
        $n->save();
        return redirect()->route('networks.edit',$n)->with('status','Created.');
    }

    public function update(Request $r, Network $network)
    {
        $network->name = trim((string)$r->input('name',$network->name));
        $network->save();

        $network->load(['mncs','country.mccs']);
        $primaryMcc = $network->mncs->pluck('mcc')->filter()->first()
            ?? optional($network->country?->mccs->first())->mcc
            ?? '';

        $mncs = (array) $r->input('mncs', []);
        $toDelete = array_map('intval', array_keys((array)$r->input('delete_mncs', [])));
        if ($toDelete) {
            NetworkMnc::where('network_id',$network->id)->whereIn('id',$toDelete)->delete();
        }

        foreach ($mncs as $row) {
            $id  = isset($row['id']) ? (int)$row['id'] : null;
            $mnc = trim((string)($row['mnc'] ?? ''));
            if ($mnc==='') continue;

            $nm = $id
                ? NetworkMnc::where('network_id',$network->id)->where('id',$id)->first()
                : new NetworkMnc();

            if (!$nm) $nm = new NetworkMnc();
            $nm->network_id = $network->id;
            $nm->mcc = (string)$primaryMcc;
            $nm->mnc = $mnc;
            $nm->mcc_mnc = ((string)$primaryMcc).$mnc;
            $nm->save();
        }

        return redirect()->route('networks.edit',$network)->with('status','Saved.');
    }

    public function destroy(Network $network)
    {
        $network->delete();
        return back()->with('status','Deleted.');
    }
}
