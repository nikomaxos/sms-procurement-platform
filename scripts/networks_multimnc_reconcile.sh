#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

echo "==> 0) Ensure dirs"
mkdir -p app/Models app/Http/Controllers resources/views/networks database/migrations

###############################################################################
# 1) Migration: network_mncs + audit on networks + legacy backfill
###############################################################################
ts="$(date +%Y_%m_%d_%H%M%S)"
mig="database/migrations/${ts}_add_network_mncs_and_audit.php"
cat > "$mig" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasTable('network_mncs')) {
            Schema::create('network_mncs', function (Blueprint $t) {
                $t->id();
                $t->foreignId('network_id')->constrained('networks')->onDelete('cascade');
                $t->string('mcc', 6);
                $t->string('mnc', 6);
                $t->string('mcc_mnc', 12)->index();
                $t->boolean('marked_for_deletion')->default(false)->index();
                $t->foreignId('created_by_user_id')->nullable()->constrained('users')->nullOnDelete();
                $t->foreignId('updated_by_user_id')->nullable()->constrained('users')->nullOnDelete();
                $t->string('created_by_source')->nullable();
                $t->string('updated_by_source')->nullable();
                $t->timestamps();

                $t->unique(['mcc','mnc']);
                $t->unique(['mcc_mnc']);
            });
        }

        Schema::table('networks', function (Blueprint $t) {
            if (!Schema::hasColumn('networks','created_by_user_id')) {
                $t->foreignId('created_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            }
            if (!Schema::hasColumn('networks','updated_by_user_id')) {
                $t->foreignId('updated_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            }
            if (!Schema::hasColumn('networks','created_by_source')) { $t->string('created_by_source')->nullable(); }
            if (!Schema::hasColumn('networks','updated_by_source')) { $t->string('updated_by_source')->nullable(); }
        });

        // Backfill per-MNC rows from legacy single-MCC/MNC columns if present
        if (Schema::hasColumn('networks','mcc') && Schema::hasColumn('networks','mnc')) {
            $rows = DB::table('networks')->select('id','mcc','mnc')->whereNotNull('mcc')->whereNotNull('mnc')->get();
            foreach ($rows as $r) {
                $mcc = trim((string)$r->mcc); $mnc = trim((string)$r->mnc);
                if ($mcc==='' || $mnc==='') continue;
                $mcc_mnc = $mcc.$mnc;
                $exists = DB::table('network_mncs')->where('mcc',$mcc)->where('mnc',$mnc)->exists();
                if (!$exists) {
                    DB::table('network_mncs')->insert([
                        'network_id'=>$r->id,
                        'mcc'=>$mcc, 'mnc'=>$mnc, 'mcc_mnc'=>$mcc_mnc,
                        'created_at'=>now(), 'updated_at'=>now(),
                    ]);
                }
            }
        }
    }

    public function down(): void {
        if (Schema::hasTable('network_mncs')) Schema::drop('network_mncs');
        Schema::table('networks', function (Blueprint $t) {
            if (Schema::hasColumn('networks','created_by_user_id')) $t->dropConstrainedForeignId('created_by_user_id');
            if (Schema::hasColumn('networks','updated_by_user_id')) $t->dropConstrainedForeignId('updated_by_user_id');
            if (Schema::hasColumn('networks','created_by_source')) $t->dropColumn('created_by_source');
            if (Schema::hasColumn('networks','updated_by_source')) $t->dropColumn('updated_by_source');
        });
    }
};
PHP

###############################################################################
# 2) Models: Network & NetworkMnc
###############################################################################
cat > app/Models/NetworkMnc.php <<'PHP'
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class NetworkMnc extends Model {
    use HasFactory;
    protected $fillable = [
        'network_id','mcc','mnc','mcc_mnc','marked_for_deletion',
        'created_by_user_id','updated_by_user_id','created_by_source','updated_by_source'
    ];

    protected static function booted() {
        static::saving(function(self $m){
            $m->mcc = trim((string)$m->mcc);
            $m->mnc = trim((string)$m->mnc);
            $m->mcc_mnc = $m->mcc.$m->mnc;
        });
    }

    public function network(){ return $this->belongsTo(Network::class); }
    public function creator(){ return $this->belongsTo(User::class, 'created_by_user_id'); }
    public function updater(){ return $this->belongsTo(User::class, 'updated_by_user_id'); }
}
PHP

cat > app/Models/Network.php <<'PHP'
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Network extends Model {
    use HasFactory;

    protected $fillable = [
        'name','country_id','created_by_user_id','updated_by_user_id','created_by_source','updated_by_source'
    ];

    public function country(){ return $this->belongsTo(Country::class); }
    public function mncs(){ return $this->hasMany(NetworkMnc::class); }
    public function creator(){ return $this->belongsTo(User::class,'created_by_user_id'); }
    public function updater(){ return $this->belongsTo(User::class,'updated_by_user_id'); }

    public function getMncListAttribute(){
        $vals = $this->mncs->pluck('mnc')->filter()->unique()->sort()->values()->all();
        return implode(', ', $vals);
    }
}
PHP

###############################################################################
# 3) NetworksController (index filters, grouping, edit nested MNCs)
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
        if (!in_array($per,[20,50,100,1000])) $per=20;

        // Build an aggregated query for sorting by Country then MCC-MNC (min)
        $q = Network::query()
            ->leftJoin('countries','countries.id','=','networks.country_id')
            ->leftJoin('network_mncs','network_mncs.network_id','=','networks.id')
            ->select(
                'networks.*',
                'countries.name as country_name',
                DB::raw("MIN(network_mncs.mcc_mnc) as first_mccmnc")
            )
            ->when($r->filled('q'), function($qq) use($r){
                $s = $r->q;
                $qq->where(function($w) use($s){
                    $w->where('networks.name','ilike',"%$s%")
                      ->orWhere('countries.name','ilike',"%$s%");
                });
            })
            ->when($r->filled('country'), fn($qq)=>$qq->where('countries.name','ilike','%'.$r->country.'%'))
            ->when($r->filled('mcc'), fn($qq)=>$qq->where('network_mncs.mcc','ilike','%'.$r->mcc.'%'))
            ->when($r->filled('mnc'), fn($qq)=>$qq->where('network_mncs.mnc','ilike','%'.$r->mnc.'%'))
            ->when($r->filled('mcc_mnc'), fn($qq)=>$qq->where('network_mncs.mcc_mnc','ilike','%'.$r->mcc_mnc.'%'))
            ->when($r->boolean('flagged'), fn($qq)=>$qq->where('network_mncs.marked_for_deletion',true))
            ->groupBy('networks.id','countries.name')
            ->orderBy('countries.name')
            ->orderBy('first_mccmnc');

        $networks = $q->paginate($per)->appends($r->all());
        $networks->loadMissing(['mncs','country']);

        return view('networks.index', compact('networks','per'));
    }

    public function create(){
        $countries = Country::orderBy('name')->get();
        $network = new Network();
        $network->setRelation('mncs', collect([new NetworkMnc(['mcc'=>'','mnc'=>''])]));
        return view('networks.create', compact('network','countries'));
    }

    public function store(Request $r){
        $data = $r->validate([
            'name' => 'required|string|max:255',
            'country_id' => 'required|exists:countries,id',
            'mncs' => 'array',
            'mncs.*.mcc' => 'nullable|string|max:6',
            'mncs.*.mnc' => 'nullable|string|max:6',
        ]);
        $u = $r->user();

        $n = new Network([
            'name'=>$data['name'],
            'country_id'=>$data['country_id'],
            'created_by_user_id'=>$u?->id,
            'updated_by_user_id'=>$u?->id,
            'created_by_source'=>null,
            'updated_by_source'=>null,
        ]);
        $n->save();

        foreach (($data['mncs'] ?? []) as $row) {
            $mcc = trim((string)($row['mcc'] ?? ''));
            $mnc = trim((string)($row['mnc'] ?? ''));
            if ($mcc==='' || $mnc==='') continue;
            $n->mncs()->create([
                'mcc'=>$mcc,'mnc'=>$mnc,
                'marked_for_deletion'=>false,
                'created_by_user_id'=>$u?->id,'updated_by_user_id'=>$u?->id
            ]);
        }
        return redirect()->route('networks.index')->with('status','Network created.');
    }

    public function edit(Network $network){
        $countries = Country::orderBy('name')->get();
        $network->load(['mncs.creator','mncs.updater','creator','updater','country']);
        if ($network->mncs->isEmpty()) $network->setRelation('mncs', collect([new NetworkMnc(['mcc'=>'','mnc'=>''])]));
        return view('networks.edit', compact('network','countries'));
    }

    public function update(Request $r, Network $network){
        $data = $r->validate([
            'name' => 'required|string|max:255',
            'country_id' => 'required|exists:countries,id',
            'mncs' => 'array',
            'mncs.*.id' => 'nullable|integer',
            'mncs.*.mcc' => 'nullable|string|max:6',
            'mncs.*.mnc' => 'nullable|string|max:6',
            'mncs.*.marked_for_deletion' => 'nullable|boolean',
        ]);
        $u = $r->user();

        $network->fill([
            'name'=>$data['name'],
            'country_id'=>$data['country_id'],
            'updated_by_user_id'=>$u?->id,
            'updated_by_source'=>null,
        ])->save();

        $seen = [];
        foreach (($data['mncs'] ?? []) as $row) {
            $id  = $row['id'] ?? null;
            $mcc = trim((string)($row['mcc'] ?? ''));
            $mnc = trim((string)($row['mnc'] ?? ''));
            $flag = (bool)($row['marked_for_deletion'] ?? false);
            if ($mcc==='' || $mnc==='') continue;

            if ($id) {
                $m = $network->mncs()->whereKey($id)->first();
                if ($m) {
                    $m->fill([
                        'mcc'=>$mcc,'mnc'=>$mnc,
                        'marked_for_deletion'=>$flag,
                        'updated_by_user_id'=>$u?->id,'updated_by_source'=>null,
                    ])->save();
                    $seen[] = $m->id;
                }
            } else {
                $m = $network->mncs()->firstOrCreate(
                    ['mcc'=>$mcc,'mnc'=>$mnc],
                    [
                        'marked_for_deletion'=>$flag,
                        'created_by_user_id'=>$u?->id,'updated_by_user_id'=>$u?->id
                    ]
                );
                $seen[] = $m->id;
            }
        }

        // Delete MNCs removed in form
        $network->mncs()->whereNotIn('id',$seen)->delete();

        return back()->with('status','Network updated.');
    }

    public function destroy(Network $network){
        $network->delete();
        return redirect()->route('networks.index')->with('status','Network deleted.');
    }
}
PHP

###############################################################################
# 4) Views: networks index/create/edit (grouped, filters, buttons, bottom paging)
###############################################################################
# INDEX
cat > resources/views/networks/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2></x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <!-- Top actions -->
    <div class="mb-4 flex flex-wrap items-center gap-3">
      <a href="{{ route('networks.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Network</a>
      <form method="POST" action="{{ route('carriers.import') }}">
        @csrf
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Fresh import (ITU)</button>
      </form>
    </div>

    <!-- Filters -->
    <form method="GET" class="mb-4 flex flex-wrap items-center gap-2">
      <input name="q" value="{{ request('q') }}" placeholder="Search name or country…" class="rounded border px-3 py-2">
      <input name="country" value="{{ request('country') }}" placeholder="Country" class="rounded border px-3 py-2">
      <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC" class="rounded border px-3 py-2">
      <input name="mnc" value="{{ request('mnc') }}" placeholder="MNC" class="rounded border px-3 py-2">
      <input name="mcc_mnc" value="{{ request('mcc_mnc') }}" placeholder="MCC-MNC" class="rounded border px-3 py-2">
      <label class="flex items-center gap-2 ml-3">
        <input type="checkbox" name="flagged" value="1" @checked(request()->boolean('flagged'))>
        <span>Marked for deletion</span>
      </label>
      <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
    </form>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">Network</th>
            <th class="px-3 py-2 text-left">MCC</th>
            <th class="px-3 py-2 text-left">MNCs</th>
            <th class="px-3 py-2 text-left">Updated</th>
            <th class="px-3 py-2 text-left">Updated by</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($networks as $n)
            @php
              $mccs = $n->mncs->pluck('mcc')->unique()->sort()->values()->all();
              $mnc_list = $n->mncs->pluck('mnc')->unique()->sort()->values()->implode(', ');
              $has_flag = $n->mncs->where('marked_for_deletion', true)->isNotEmpty();
              $updated_by = optional($n->updater)->name ?? ($n->updated_by_source ?? '');
            @endphp
            <tr class="border-t {{ $has_flag ? 'bg-yellow-50' : '' }}">
              <td class="px-3 py-2">{{ $n->country?->name }}</td>
              <td class="px-3 py-2">{{ $n->name }}</td>
              <td class="px-3 py-2">{{ implode(', ', $mccs) }}</td>
              <td class="px-3 py-2">{{ $mnc_list }}</td>
              <td class="px-3 py-2">{{ optional($n->updated_at)->format('Y-m-d H:i') }}</td>
              <td class="px-3 py-2">{{ $updated_by }}</td>
              <td class="px-3 py-2 text-right">
                <a href="{{ route('networks.edit',$n) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
                <form action="{{ route('networks.destroy',$n) }}" method="POST" class="inline" onsubmit="return confirm('Delete this network?');">
                  @csrf @method('DELETE')
                  <button class="rounded px-3 py-2 bg-red-600 text-white hover:bg-red-700">Delete</button>
                </form>
              </td>
            </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <!-- Bottom pager with per-page selector -->
    <div class="mt-3 flex items-center justify-between">
      <div>
        <form method="GET" class="inline">
          @foreach (request()->except('per') as $k=>$v)
            <input type="hidden" name="{{ $k }}" value="{{ $v }}">
          @endforeach
          <label>Per page:
            <select name="per" class="border rounded px-2 py-1" onchange="this.form.submit()">
              @foreach ([20,50,100,1000] as $opt)
                <option value="{{ $opt }}" @selected($per==$opt)>{{ $opt }}</option>
              @endforeach
            </select>
          </label>
        </form>
      </div>
      <div>{{ $networks->links() }}</div>
    </div>
  </div>
</x-app-layout>
BLADE

# CREATE + EDIT share the same form
cat > resources/views/networks/_form.blade.php <<'BLADE'
@csrf
<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div>
    <label class="block text-sm font-medium mb-1">Network name</label>
    <input name="name" value="{{ old('name', $network->name) }}" class="w-full rounded border px-3 py-2">
  </div>
  <div>
    <label class="block text-sm font-medium mb-1">Country</label>
    <select name="country_id" class="w-full rounded border px-3 py-2">
      @foreach ($countries as $c)
        <option value="{{ $c->id }}" @selected(old('country_id', $network->country_id)==$c->id)>{{ $c->name }}</option>
      @endforeach
    </select>
  </div>
</div>

@if($network->exists)
  <div class="mt-4 text-sm text-gray-600">
    <div>Created: {{ optional($network->created_at)->format('Y-m-d H:i') }} • by {{ optional($network->creator)->name ?? ($network->created_by_source ?? '') }}</div>
    <div>Updated: {{ optional($network->updated_at)->format('Y-m-d H:i') }} • by {{ optional($network->updater)->name ?? ($network->updated_by_source ?? '') }}</div>
  </div>
@endif

<hr class="my-4">

<div class="mb-2 font-semibold">MNCs under this Network</div>
<div id="mncs">
  @php $rows = old('mncs', $network->mncs->map(fn($m)=>[
      'id'=>$m->id, 'mcc'=>$m->mcc, 'mnc'=>$m->mnc, 'marked_for_deletion'=>$m->marked_for_deletion,
      'created_at'=>optional($m->created_at)->format('Y-m-d H:i'),
      'updated_at'=>optional($m->updated_at)->format('Y-m-d H:i'),
      'creator'=>optional($m->creator)->name ?? ($m->created_by_source ?? ''),
      'updater'=>optional($m->updater)->name ?? ($m->updated_by_source ?? ''),
  ])->toArray()); @endphp

  @foreach ($rows as $i => $row)
    <div class="grid grid-cols-1 md:grid-cols-5 gap-3 items-end mb-3 border rounded p-3">
      <input type="hidden" name="mncs[{{ $i }}][id]" value="{{ $row['id'] ?? '' }}">
      <div>
        <label class="block text-sm font-medium mb-1">MCC</label>
        <input name="mncs[{{ $i }}][mcc]" value="{{ $row['mcc'] ?? '' }}" class="w-full rounded border px-3 py-2">
      </div>
      <div>
        <label class="block text-sm font-medium mb-1">MNC</label>
        <input name="mncs[{{ $i }}][mnc]" value="{{ $row['mnc'] ?? '' }}" class="w-full rounded border px-3 py-2">
      </div>
      <div>
        <label class="block text-sm font-medium mb-1">MCC-MNC</label>
        <input value="{{ ($row['mcc'] ?? '').($row['mnc'] ?? '') }}" class="w-full rounded border px-3 py-2 bg-gray-100" readonly>
      </div>
      <div class="flex items-center gap-2">
        <input type="checkbox" name="mncs[{{ $i }}][marked_for_deletion]" value="1" @checked(!empty($row['marked_for_deletion']))>
        <span>Marked for deletion</span>
      </div>
      <div class="text-xs text-gray-600">
        <div>Created: {{ $row['created_at'] ?? '' }} • {{ $row['creator'] ?? '' }}</div>
        <div>Updated: {{ $row['updated_at'] ?? '' }} • {{ $row['updater'] ?? '' }}</div>
      </div>
    </div>
  @endforeach

  {{-- one extra empty row --}}
  <div class="grid grid-cols-1 md:grid-cols-5 gap-3 items-end mb-3 border rounded p-3">
    <div class="md:col-span-1">
      <label class="block text-sm font-medium mb-1">MCC</label>
      <input name="mncs[999][mcc]" value="" class="w-full rounded border px-3 py-2">
    </div>
    <div class="md:col-span-1">
      <label class="block text-sm font-medium mb-1">MNC</label>
      <input name="mncs[999][mnc]" value="" class="w-full rounded border px-3 py-2">
    </div>
    <div class="md:col-span-3 text-xs text-gray-600">
      <div>Add another MNC by filling MCC & MNC here; you can add more after saving.</div>
    </div>
  </div>
</div>
BLADE

cat > resources/views/networks/create.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Add Network</h2></x-slot>
  <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.store') }}" class="space-y-4">
      @include('networks._form')
      <div class="flex items-center gap-3">
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
  <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="POST" action="{{ route('networks.update',$network) }}" class="space-y-4">
      @method('PUT')
      @include('networks._form')
      <div class="flex items-center gap-3">
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Update</button>
        <a href="{{ route('networks.index') }}" class="rounded px-4 py-2 bg-gray-200 hover:bg-gray-300">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

###############################################################################
# 5) Importer (reconcile; append/update; mark-missing)
#     Uses onomondo/mcc-mnc-itu CSV primarily; falls back to musalbas JSON.
###############################################################################
cat > app/Console/Commands/ImportCarriers.php <<'PHP'
<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use App\Models\Country;
use App\Models\Network;
use App\Models\NetworkMnc;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--fresh : Ignore local deletes; still non-destructive}';
    protected $description = 'Reconcile Countries & Networks (multi-MNC) with ITU dataset. No hard deletes; mark missing MNCs.';

    private string $csvUrl = 'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/mcc-mnc.csv';
    private string $jsonFallback = 'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json';

    public function handle(): int {
        $sourceName = 'ITU import';

        $fetch = function(string $url): ?string {
            $ctx = stream_context_create(['http'=>['timeout'=>30],'https'=>['timeout'=>30]]);
            $raw = @file_get_contents($url,false,$ctx);
            return $raw===false?null:$raw;
        };

        $rows = [];

        // Try Onomondo CSV
        if ($csv = $fetch($this->csvUrl)) {
            $lines = preg_split("/\r\n|\n|\r/", trim($csv));
            if ($lines && count($lines)>1) {
                $hdr = array_map('strtolower', str_getcsv(array_shift($lines)));
                foreach ($lines as $ln) {
                    if ($ln==='') continue;
                    $cols = str_getcsv($ln);
                    $row = array_combine($hdr, array_pad($cols, count($hdr), null));
                    if (!$row) continue;

                    $country = trim((string)($row['country'] ?? $row['country_name'] ?? ''));
                    $iso = strtolower(trim((string)($row['iso'] ?? $row['iso2'] ?? '')));
                    $mcc = trim((string)($row['mcc'] ?? ''));
                    $mnc = trim((string)($row['mnc'] ?? ''));
                    $name = trim((string)($row['brand'] ?? $row['operator'] ?? $row['network'] ?? ''));

                    if ($country==='' || $mcc==='' || $mnc==='' || $name==='') continue;
                    if (!preg_match('/^[a-z]{2}$/',$iso)) continue; // skip invalid ISO like 'n/a'

                    $rows[] = compact('country','iso','mcc','mnc','name');
                }
            }
        }

        // Fallback: Musalbas JSON
        if (!$rows) {
            if ($raw = $fetch($this->jsonFallback)) {
                $j = json_decode($raw,true);
                if (is_array($j)) foreach ($j as $row) {
                    $country = trim((string)($row['country'] ?? $row['country_name'] ?? ''));
                    $iso = strtolower(trim((string)($row['iso'] ?? $row['iso2'] ?? '')));
                    $mcc = trim((string)($row['mcc'] ?? ''));
                    $mnc = trim((string)($row['mnc'] ?? ''));
                    $name = trim((string)($row['brand'] ?? $row['operator'] ?? $row['network'] ?? ''));
                    if ($country==='' || $mcc==='' || $mnc==='' || $name==='') continue;
                    if (!preg_match('/^[a-z]{2}$/',$iso)) continue;
                    $rows[] = compact('country','iso','mcc','mnc','name');
                }
            }
        }

        if (!$rows) { $this->error("No data fetched."); return 1; }

        // Group by (country_iso, mcc, normalized_name) -> list of MNCs
        $grouped = [];
        foreach ($rows as $r) {
            $key = strtolower($r['iso']).'|'.$r['mcc'].'|'.preg_replace('/\s+/',' ',strtolower($r['name']));
            $grouped[$key]['country'] = $r['country'];
            $grouped[$key]['iso'] = strtolower($r['iso']);
            $grouped[$key]['mcc'] = $r['mcc'];
            $grouped[$key]['name'] = $r['name'];
            $grouped[$key]['mncs'][] = $r['mnc'];
        }

        $import_mccmnc = []; // track all mcc_mnc seen in import to later unflag/flag

        DB::transaction(function() use ($grouped, &$import_mccmnc, $sourceName) {
            foreach ($grouped as $g) {
                // Country
                $country = Country::firstOrCreate(
                    ['name'=>$g['country']],
                    ['iso2'=>$g['iso'] ?: null]
                );

                // Network (grouped by name within country)
                $network = Network::firstOrCreate(
                    ['name'=>$g['name'], 'country_id'=>$country->id],
                    ['created_by_source'=>$sourceName, 'updated_by_source'=>$sourceName]
                );
                $network->update(['updated_by_source'=>$sourceName]);

                // Ensure each MNC exists under this network; unflag it
                $mncs = array_values(array_unique($g['mncs']));
                foreach ($mncs as $mnc) {
                    $m = NetworkMnc::firstOrCreate(
                        ['mcc'=>$g['mcc'], 'mnc'=>$mnc],
                        ['network_id'=>$network->id, 'created_by_source'=>$sourceName]
                    );
                    if ($m->network_id !== $network->id) {
                        $m->network_id = $network->id;
                    }
                    $m->marked_for_deletion = false;
                    $m->updated_by_source = $sourceName;
                    $m->save();

                    $import_mccmnc[] = $g['mcc'].$mnc;
                }

                // For any existing MNCs of this network with same MCC but not in import set for this group, mark flagged
                $network->mncs()
                    ->where('mcc', $g['mcc'])
                    ->whereNotIn('mnc', $mncs)
                    ->update(['marked_for_deletion'=>true, 'updated_by_source'=>$sourceName]);
            }
        });

        // Globally flag any local MNC not seen in import at all; unflag those that reappeared
        $import_mccmnc = array_unique($import_mccmnc);
        DB::table('network_mncs')->whereNotIn('mcc_mnc', $import_mccmnc)->update([
            'marked_for_deletion'=>true, 'updated_by_source'=>$sourceName, 'updated_at'=>now()
        ]);
        DB::table('network_mncs')->whereIn('mcc_mnc', $import_mccmnc)->update([
            'marked_for_deletion'=>false, 'updated_by_source'=>$sourceName, 'updated_at'=>now()
        ]);

        $this->info("Import complete. Networks: ".Network::count()." | MNCs: ".\App\Models\NetworkMnc::count());
        return 0;
    }
}
PHP

###############################################################################
# 6) Countries controller untouched. Run migrate + cache warm + perms.
###############################################################################
echo "==> 6) Migrate"
$DC exec -T app sh -lc 'php artisan migrate --force'

echo "==> 7) Clear caches / rebuild"
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "==> 8) Fix storage perms (in case Blade cache fails later)"
$DC exec -T app sh -lc '
  set -e
  install -d -m 0777 storage/framework/{cache,sessions,views} bootstrap/cache
  chmod -R 0777 storage bootstrap/cache
'

echo "==> Done. Go to /networks, use “Fresh import (ITU)”, then filter/search as needed."
