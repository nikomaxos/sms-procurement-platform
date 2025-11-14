#!/usr/bin/env bash
set -Eeuo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Backup old controller (if any)"
mkdir -p app/Http/Controllers
[ -f app/Http/Controllers/NetworksController.php ] && \
  cp -a app/Http/Controllers/NetworksController.php app/Http/Controllers/NetworksController.php.bak.$(date +%F_%H-%M-%S) || true

echo "==> Write safe NetworksController (no string interpolation issues)"
cat > app/Http/Controllers/NetworksController.php <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Schema;
use App\Models\Country;
use App\Models\Network;
use App\Models\NetworkMnc;

class NetworksController extends Controller {
    public function __construct(){ $this->middleware('auth'); }

    public function index(Request $r){
        $per = max(1, min(1000, (int)$r->query('per', 20)));
        $q = Network::with(['country','mncs'])
            ->when($r->filled('q'),        fn($qq)=>$qq->where('name','ilike','%'.$r->q.'%'))
            ->when($r->filled('country'),  fn($qq)=>$qq->whereHas('country', fn($c)=>$c->where('name','ilike','%'.trim($r->country).'%')))
            ->when($r->filled('mcc'),      fn($qq)=>$qq->whereHas('mncs', fn($m)=>$m->where('mcc', trim($r->mcc))))
            ->when($r->filled('mnc'),      fn($qq)=>$qq->whereHas('mncs', fn($m)=>$m->where('mnc', trim($r->mnc))))
            ->when($r->filled('mcc_mnc'),  fn($qq)=>$qq->whereHas('mncs', fn($m)=>$m->where('mcc_mnc','ilike','%'.trim($r->mcc_mnc).'%')))
            ->join('countries','countries.id','=','networks.country_id')
            ->orderBy('countries.name')
            ->orderByRaw("(select coalesce(min(m.mcc||m.mnc), '')) asc")
            ->select('networks.*');

        $networks = $q->paginate($per)->appends($r->all());
        return view('networks.index', compact('networks'));
    }

    public function create(){
        $countries = Country::orderBy('name')->get();
        return view('networks.create', compact('countries'));
    }

    public function store(Request $r){
        $r->validate([
            'country_id' => 'required|exists:countries,id',
            'name'       => 'required|string|max:255',
            'primary_mcc'=> 'nullable|string|max:6'
        ]);

        $net = new Network();
        $net->country_id   = (int)$r->country_id;
        $net->name         = trim($r->name);
        if (Schema::hasColumn('networks','primary_mcc')) $net->primary_mcc = trim((string)$r->primary_mcc);
        if (Schema::hasColumn('networks','created_by_user')) $net->created_by_user = Auth::user()->name ?? null;
        $net->save();

        $mncs = (array)$r->input('mncs', []);
        foreach ($mncs as $row){
            $mcc = isset($row['mcc']) ? trim((string)$row['mcc']) : '';
            $mnc = isset($row['mnc']) ? trim((string)$row['mnc']) : '';
            if ($mcc!=='' && $mnc!=='') {
                NetworkMnc::firstOrCreate(
                    ['network_id'=>$net->id,'mcc'=>$mcc,'mnc'=>$mnc],
                    ['created_by_user'=>Auth::user()->name ?? null]
                );
            }
        }

        return redirect()->route('networks.index')->with('status','Network created.');
    }

    public function edit(Network $network){
        $network->load(['country','mncs']);
        $primaryMcc = $network->primary_mcc ?? ($network->mncs->first()->mcc ?? '');
        return view('networks.edit', compact('network','primaryMcc'));
    }

    public function update(Request $r, Network $network){
        $r->validate([
            'name'        => 'required|string|max:255',
            'primary_mcc' => 'nullable|string|max:6'
        ]);

        $network->name = trim($r->name);
        if (Schema::hasColumn('networks','primary_mcc')) $network->primary_mcc = trim((string)$r->primary_mcc);
        if (Schema::hasColumn('networks','updated_by_user')) $network->updated_by_user = Auth::user()->name ?? null;
        $network->save();

        // deletions (one confirm in the view)
        $toRemove = (array)$r->input('remove_mnc', []);
        foreach ($toRemove as $rm){
            if (is_numeric($rm)) {
                NetworkMnc::where('id',(int)$rm)->where('network_id',$network->id)->delete();
            }
        }

        // upserts
        $mncs = (array)$r->input('mncs', []);
        foreach ($mncs as $row){
            $id  = isset($row['id']) ? (int)$row['id'] : null;
            $mcc = isset($row['mcc']) ? trim((string)$row['mcc']) : '';
            $mnc = isset($row['mnc']) ? trim((string)$row['mnc']) : '';
            if ($mcc==='' || $mnc==='') continue;

            if ($id) {
                $m = NetworkMnc::where('id',$id)->where('network_id',$network->id)->first();
                if ($m) {
                    $m->mcc = $mcc;
                    $m->mnc = $mnc;
                    if (Schema::hasColumn('network_mncs','updated_by_user')) $m->updated_by_user = Auth::user()->name ?? null;
                    $m->save();
                }
            } else {
                NetworkMnc::firstOrCreate(
                    ['network_id'=>$network->id,'mcc'=>$mcc,'mnc'=>$mnc],
                    ['created_by_user'=>Auth::user()->name ?? null]
                );
            }
        }

        return redirect()->route('networks.edit',$network)->with('status','Network saved.');
    }

    public function destroy(Network $network){
        $network->mncs()->delete();
        $network->delete();
        return redirect()->route('networks.index')->with('status','Network deleted.');
    }
}
PHP

echo "==> Warm caches"
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'
echo "Done: NetworksController repaired."
