#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

mkdir -p app/Models app/Http/Controllers resources/views/networks database/migrations

###############################################################################
# 1) Models: Network + NetworkMnc relationships & helpers
###############################################################################
cat > app/Models/NetworkMnc.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMnc extends Model {
    protected $fillable = [
        'network_id','mcc','mnc','mcc_mnc',
        'marked_for_deletion','created_by_user_id','updated_by_user_id',
        'created_by_source','updated_by_source'
    ];
    protected $casts = ['marked_for_deletion'=>'bool'];

    public function network(): BelongsTo { return $this->belongsTo(Network::class); }
    public function createdByUser(){ return $this->belongsTo(\App\Models\User::class,'created_by_user_id'); }
    public function updatedByUser(){ return $this->belongsTo(\App\Models\User::class,'updated_by_user_id'); }
}
PHP

cat > app/Models/Network.php <<'PHP'
<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Network extends Model {
    protected $fillable = [
        'name','country_id','marked_for_deletion',
        'created_by_user_id','updated_by_user_id','created_by_source','updated_by_source'
    ];
    protected $casts = ['marked_for_deletion'=>'bool'];

    public function country(): BelongsTo { return $this->belongsTo(Country::class); }
    public function mncs(): HasMany { return $this->hasMany(NetworkMnc::class)->orderBy('mnc'); }

    # Helpers for list view
    public function getMccListAttribute() {
        return $this->mncs->pluck('mcc')->filter()->unique()->values();
    }
    public function getMncListAttribute() {
        return $this->mncs->pluck('mnc')->filter()->values();
    }
    public function getAnyMccMncAttribute() {
        $m=$this->mncs->first(); return $m ? $m->mcc.$m->mnc : null;
    }
}
PHP

###############################################################################
# 2) Migration: add networks.marked_for_deletion (safe if exists)
###############################################################################
ts="$(date +%Y_%m_%d_%H%M%S)"
mig="database/migrations/${ts}_add_marked_flag_to_networks.php"
cat > "$mig" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasColumn('networks','marked_for_deletion')) {
            Schema::table('networks', function (Blueprint $t) {
                $t->boolean('marked_for_deletion')->default(false)->index();
            });
        }
    }
    public function down(): void { /* keep */ }
};
PHP

###############################################################################
# 3) Controller: robust edit/update with nested MNCs
###############################################################################
cat > app/Http/Controllers/NetworksController.php <<'PHP'
<?php
namespace App\Http\Controllers;

use App\Models\Network;
use App\Models\NetworkMnc;
use App\Models\Country;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class NetworksController extends Controller {
    public function __construct(){ $this->middleware('auth'); }

    public function index(Request $r){
        $per = (int)($r->integer('per') ?: 20);
        $per = in_array($per,[20,50,100,1000],true) ? $per : 20;

        $q = Network::query()
            ->with(['country:id,name','mncs:id,network_id,mcc,mnc,mcc_mnc,marked_for_deletion'])
            ->leftJoin('countries','countries.id','=','networks.country_id')
            ->leftJoin('network_mncs','network_mncs.network_id','=','networks.id')
            ->select('networks.*','countries.name as country_name', DB::raw('MIN(network_mncs.mcc_mnc) as min_mccmnc'))
            ->when($r->filled('q'), fn($qq)=>$qq->where('networks.name','ilike','%'.$r->q.'%'))
            ->when($r->filled('country'), fn($qq)=>$qq->where('countries.name','ilike','%'.$r->country.'%'))
            ->when($r->filled('mcc'), fn($qq)=>$qq->where('network_mncs.mcc',$r->mcc))
            ->when($r->filled('mnc'), fn($qq)=>$qq->where('network_mncs.mnc',$r->mnc))
            ->when($r->filled('mcc_mnc'), fn($qq)=>$qq->where('network_mncs.mcc_mnc','ilike','%'.$r->mcc_mnc.'%'))
            ->when($r->filled('flagged'), fn($qq)=>$qq->where('networks.marked_for_deletion', (bool)$r->boolean('flagged')))
            ->groupBy('networks.id','countries.name')
            ->orderBy('country_name')->orderBy('min_mccmnc');

        $networks = $q->paginate($per)->appends($r->all());
        return view('networks.index', compact('networks','per'));
    }

    public function create(){
        $countries = Country::orderBy('name')->get(['id','name']);
        $network = new Network();
        $network->setRelation('mncs', collect());
        $primaryMcc = $this->primaryMccForCountry(null); // none yet
        return view('networks.create', compact('network','countries','primaryMcc'));
    }

    public function edit(Network $network){
        $network->load(['mncs','country.mccs']);
        $countries = Country::orderBy('name')->get(['id','name']);
        $primaryMcc = $this->primaryMccForCountry($network->country_id, $network);
        return view('networks.edit', compact('network','countries','primaryMcc'));
    }

    public function store(Request $r){
        return $this->upsert($r, new Network());
    }
    public function update(Request $r, Network $network){
        return $this->upsert($r, $network);
    }

    private function upsert(Request $r, Network $network){
        $data = $r->validate([
            'name' => 'required|string|max:255',
            'country_id' => 'required|exists:countries,id',
            'marked_for_deletion' => 'sometimes|boolean',
            'mncs_existing' => 'array',
            'mncs_existing.*.mnc' => 'nullable|string|max:12',
            'mncs_existing.*.delete' => 'nullable|boolean',
            'mncs_new' => 'array',
            'mncs_new.*' => 'nullable|string|max:12',
        ]);

        DB::transaction(function() use ($r, $network, $data) {
            $user = $r->user();
            $network->name = $data['name'];
            $network->country_id = $data['country_id'];
            $network->marked_for_deletion = (bool)($data['marked_for_deletion'] ?? false);
            $network->updated_by_user_id = $user?->id;
            $network->updated_by_source = null;
            if (!$network->exists) {
                $network->created_by_user_id = $user?->id;
                $network->created_by_source = null;
            }
            $network->save();

            $primaryMcc = $this->primaryMccForCountry($network->country_id, $network);

            // Existing rows: update / delete
            foreach (($data['mncs_existing'] ?? []) as $id => $row) {
                $m = NetworkMnc::find($id);
                if(!$m || $m->network_id !== $network->id) continue;
                if (!empty($row['delete'])) { $m->delete(); continue; }
                $mnc = preg_replace('/\D+/','', (string)($row['mnc'] ?? ''));
                if ($mnc === '') { $m->delete(); continue; }
                $m->mcc = $m->mcc ?: $primaryMcc;
                $m->mnc = $mnc;
                $m->mcc_mnc = ($m->mcc ?? $primaryMcc) . $mnc;
                $m->updated_by_user_id = $user?->id;
                $m->updated_by_source = null;
                $m->save();
            }

            // New rows
            foreach (($data['mncs_new'] ?? []) as $raw) {
                $mnc = preg_replace('/\D+/','', (string)$raw);
                if ($mnc==='') continue;
                NetworkMnc::firstOrCreate(
                    ['mcc_mnc' => $primaryMcc.$mnc],
                    [
                        'network_id' => $network->id,
                        'mcc' => $primaryMcc,
                        'mnc' => $mnc,
                        'marked_for_deletion' => false,
                        'created_by_user_id' => $user?->id,
                        'updated_by_user_id' => $user?->id,
                    ]
                );
            }

            // Refresh and compute network-level marked flag (true if all MNCs flagged)
            $network->load('mncs');
            if ($network->mncs->count() > 0) {
                $allFlagged = $network->mncs->every(fn($m)=>$m->marked_for_deletion);
                $network->marked_for_deletion = $allFlagged;
                $network->save();
            }
        });

        return redirect()->route('networks.edit', $network)->with('status','Saved.');
    }

    private function primaryMccForCountry(?int $countryId, ?Network $network=null): string {
        if ($countryId) {
            $row = DB::table('country_mccs')->where('country_id',$countryId)->orderBy('mcc')->first();
            if ($row && $row->mcc) return (string)$row->mcc;
        }
        if ($network && $network->relationLoaded('mncs') && $network->mncs->first()?->mcc) {
            return (string)$network->mncs->first()->mcc;
        }
        return '';
    }

    public function destroy(Network $network){
        $network->delete();
        return redirect()->route('networks.index')->with('status','Deleted.');
    }
}
PHP

###############################################################################
# 4) Views: index + form + edit + create
###############################################################################
cat > resources/views/networks/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2></x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-2 mb-4">
      <a href="{{ route('networks.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Network</a>
      <form method="POST" action="{{ route('carriers.import') }}" class="ml-2">
        @csrf
        <input type="hidden" name="fresh" value="1">
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700">Fresh import</button>
      </form>
    </div>

    <form method="GET" class="flex flex-wrap items-center gap-2 mb-3">
      <input name="q" value="{{ request('q') }}" placeholder="Name…" class="rounded border px-3 py-2">
      <input name="country" value="{{ request('country') }}" placeholder="Country…" class="rounded border px-3 py-2">
      <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC…" class="rounded border px-3 py-2">
      <input name="mnc" value="{{ request('mnc') }}" placeholder="MNC…" class="rounded border px-3 py-2">
      <input name="mcc_mnc" value="{{ request('mcc_mnc') }}" placeholder="MCC-MNC…" class="rounded border px-3 py-2">
      <label class="inline-flex items-center gap-2 text-sm ml-2">
        <input type="checkbox" name="flagged" value="1" {{ request('flagged') ? 'checked' : '' }}> Marked for deletion
      </label>
      <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Filter</button>
    </form>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">Network</th>
            <th class="px-3 py-2 text-left">MCC(s)</th>
            <th class="px-3 py-2 text-left">MNCs</th>
            <th class="px-3 py-2 text-left">Marked</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($networks as $n)
          <tr class="border-t">
            <td class="px-3 py-2">{{ $n->country_name }}</td>
            <td class="px-3 py-2">{{ $n->name }}</td>
            <td class="px-3 py-2">
              @php $mccs = $n->mcc_list ?? collect(); @endphp
              @foreach($mccs as $mcc)
                <span class="inline-block rounded bg-gray-100 px-2 py-0.5 mr-1">{{ $mcc }}</span>
              @endforeach
            </td>
            <td class="px-3 py-2">
              @php $mncs = $n->mnc_list ?? collect(); @endphp
              @foreach($mncs as $mnc)
                <span class="inline-block rounded bg-gray-100 px-2 py-0.5 mr-1">{{ $mnc }}</span>
              @endforeach
            </td>
            <td class="px-3 py-2">
              @if($n->marked_for_deletion)
                <span class="inline-block rounded bg-red-100 text-red-700 px-2 py-0.5 text-xs">Yes</span>
              @else
                <span class="inline-block rounded bg-green-100 text-green-700 px-2 py-0.5 text-xs">No</span>
              @endif
            </td>
            <td class="px-3 py-2 text-right">
              <a href="{{ route('networks.edit',$n) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
              <form method="POST" action="{{ route('networks.destroy',$n) }}" class="inline" onsubmit="return confirm('Delete this network?')">
                @csrf @method('DELETE')
                <button class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Delete</button>
              </form>
            </td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="flex items-center justify-between mt-3">
      <div class="text-sm text-gray-600">Showing {{ $networks->firstItem() }}–{{ $networks->lastItem() }} of {{ $networks->total() }}</div>
      <form method="GET" class="flex items-center gap-2">
        @foreach (request()->except('per') as $k=>$v) <input type="hidden" name="{{ $k }}" value="{{ $v }}"> @endforeach
        <select name="per" class="rounded border px-2 py-1" onchange="this.form.submit()">
          @foreach([20,50,100,1000] as $opt)<option value="{{ $opt }}" {{ (int)request('per', $per)===$opt?'selected':'' }}>{{ $opt }}/page</option>@endforeach
        </select>
      </form>
    </div>
  </div>
</x-app-layout>
BLADE

cat > resources/views/networks/_form.blade.php <<'BLADE'
@php
  // $network, $countries, $primaryMcc provided by controller
@endphp

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div>
    <label class="block text-sm font-medium mb-1">Network name</label>
    <input name="name" value="{{ old('name', $network->name) }}" class="w-full rounded border px-3 py-2" required>
  </div>
  <div>
    <label class="block text-sm font-medium mb-1">Country</label>
    <select name="country_id" class="w-full rounded border px-3 py-2" required>
      @foreach($countries as $c)
        <option value="{{ $c->id }}" {{ (int)old('country_id', $network->country_id) === $c->id ? 'selected' : '' }}>{{ $c->name }}</option>
      @endforeach
    </select>
  </div>

  <div class="md:col-span-2">
    <label class="block text-sm font-medium mb-2">MNCs</label>

    <div id="mnc-rows" class="space-y-2">
      @foreach(($network->mncs ?? collect()) as $m)
      <div class="flex flex-wrap items-center gap-2 mnc-row">
        <input type="hidden" name="mncs_existing[{{ $m->id }}][id]" value="{{ $m->id }}">
        <div>
          <div class="text-xs text-gray-500 mb-0.5">MNC</div>
          <input name="mncs_existing[{{ $m->id }}][mnc]" value="{{ $m->mnc }}" class="rounded border px-3 py-2 w-28" autocomplete="off">
        </div>
        <div>
          <div class="text-xs text-gray-500 mb-0.5">MCC-MNC</div>
          <input value="{{ ($m->mcc ?? $primaryMcc).$m->mnc }}" class="rounded border px-3 py-2 bg-gray-50 w-36" readonly>
        </div>
        <label class="ml-2 text-sm inline-flex items-center gap-1">
          <input type="checkbox" name="mncs_existing[{{ $m->id }}][delete]"> remove
        </label>
        <div class="text-xs text-gray-500 ml-2">
          Created: {{ optional($m->created_at)->format('Y-m-d H:i') }}
          @if($m->created_by_user_id) by {{ optional($m->createdByUser)->name }} @elseif($m->created_by_source) by {{ $m->created_by_source }} @endif
          • Updated: {{ optional($m->updated_at)->format('Y-m-d H:i') }}
          @if($m->updated_by_user_id) by {{ optional($m->updatedByUser)->name }} @elseif($m->updated_by_source) by {{ $m->updated_by_source }} @endif
        </div>
      </div>
      @endforeach
    </div>

    <div class="mt-3 flex items-center gap-2">
      <input id="mnc-add" placeholder="Type MNC and press Enter" class="rounded border px-3 py-2 w-60" autocomplete="off">
      <span class="text-xs text-gray-500">Primary MCC: <b>{{ $primaryMcc ?: '—' }}</b></span>
    </div>

    <div id="mnc-new-container" class="mt-2 space-y-2"></div>

    <script>
    (function(){
      const input = document.getElementById('mnc-add');
      const cont  = document.getElementById('mnc-new-container');
      const primary = @json($primaryMcc ?? '');
      input.addEventListener('keydown', function(e){
        if(e.key === 'Enter'){
          e.preventDefault();
          const raw = (this.value || '').trim();
          if(!raw) return;
          const mnc = raw.replace(/\D+/g,'');
          if(!mnc) { this.value=''; return; }
          const row = document.createElement('div');
          row.className = 'flex flex-wrap items-center gap-2';
          const a = document.createElement('input');
          a.name = 'mncs_new[]';
          a.value = mnc;
          a.className = 'rounded border px-3 py-2 w-28';
          const b = document.createElement('input');
          b.readOnly = true;
          b.value = (primary||'') + mnc;
          b.className = 'rounded border px-3 py-2 bg-gray-50 w-36';
          row.appendChild(a); row.appendChild(b);
          cont.appendChild(row);
          this.value='';
        }
      });
    })();
    </script>
  </div>

  <div class="md:col-span-2">
    <label class="inline-flex items-center gap-2 text-sm">
      <input type="checkbox" name="marked_for_deletion" value="1" {{ old('marked_for_deletion', $network->marked_for_deletion) ? 'checked' : '' }}>
      Marked for deletion (network)
    </label>
  </div>

  <div class="md:col-span-2 grid grid-cols-2 gap-4">
    <div>
      <div class="text-xs text-gray-500 mb-0.5">Created</div>
      <input class="w-full rounded border px-3 py-2 bg-gray-50" value="{{ optional($network->created_at)->format('Y-m-d H:i') }} @ {{ $network->created_by_source ?: optional($network->createdByUser ?? null)->name }}" readonly>
    </div>
    <div>
      <div class="text-xs text-gray-500 mb-0.5">Updated</div>
      <input class="w-full rounded border px-3 py-2 bg-gray-50" value="{{ optional($network->updated_at)->format('Y-m-d H:i') }} @ {{ $network->updated_by_source ?: optional($network->updatedByUser ?? null)->name }}" readonly>
    </div>
  </div>
</div>
BLADE

cat > resources/views/networks/create.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Add Network</h2></x-slot>
  <div class="py-6 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.store') }}" class="space-y-4">
      @csrf
      @include('networks._form')
      <div class="flex items-center gap-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

cat > resources/views/networks/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2></x-slot>
  <div class="py-6 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif
    <form method="POST" action="{{ route('networks.update',$network) }}" class="space-y-4">
      @csrf @method('PUT')
      @include('networks._form')
      <div class="flex items-center gap-2">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
        <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

###############################################################################
# 5) Warm caches + migrate
###############################################################################
$DC exec -T app sh -lc '
  php artisan migrate --force
  php artisan optimize:clear && php artisan view:cache && php artisan route:cache
'
echo "Done: Networks edit UI fixed, list columns populated, quick-add MNC enabled, marked flag visible."
