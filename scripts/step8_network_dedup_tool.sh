#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"; b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step8: Network duplicates UI + merge action (admin-only)"

# 1) Controller
F=app/Http/Controllers/NetworkDedupController.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use App\Models\Network;
use App\Models\Country;

class NetworkDedupController extends Controller
{
    public function index(Request $request)
    {
        // Duplicates by MCC+MNC (same pair mapped to >1 networks)
        $dupByPair = DB::table('network_mncs as nm')
            ->join('networks as n', 'n.id', '=', 'nm.network_id')
            ->join('countries as c', 'c.id', '=', 'n.country_id')
            ->select(
                'nm.mcc','nm.mnc',
                DB::raw("json_agg(json_build_object('id', n.id, 'name', n.name, 'country', c.name) ORDER BY n.name) as nets"),
                DB::raw('count(*) as c')
            )
            ->groupBy('nm.mcc','nm.mnc')
            ->havingRaw('count(*) > 1')
            ->orderBy('nm.mcc')->orderBy('nm.mnc')
            ->limit(200)
            ->get();

        // Duplicates by country + normalized name
        $dupByName = DB::table('networks as n')
            ->join('countries as c', 'c.id', '=', 'n.country_id')
            ->select(
                'n.country_id','c.name as country', DB::raw('lower(n.name) as lname'),
                DB::raw("json_agg(json_build_object('id', n.id, 'name', n.name) ORDER BY n.name) as nets"),
                DB::raw('count(*) as c')
            )
            ->groupBy('n.country_id','c.name', DB::raw('lower(n.name)'))
            ->havingRaw('count(*) > 1')
            ->orderBy('country')->orderBy('lname')
            ->limit(200)
            ->get();

        return view('networks.duplicates', [
            'dupByPair' => $dupByPair,
            'dupByName' => $dupByName,
        ]);
    }

    public function merge(Request $request)
    {
        $validated = $request->validate([
            'target_id'          => ['required','integer','exists:networks,id'],
            'source_ids'         => ['required','array','min:1'],
            'source_ids.*'       => ['integer','different:target_id','exists:networks,id'],
            'reason'             => ['nullable','string','max:500'],
        ]);

        $targetId = (int)$validated['target_id'];
        $sources  = array_values(array_unique(array_map('intval', $validated['source_ids'])));
        $sources  = array_values(array_diff($sources, [$targetId]));
        if (empty($sources)) {
            return back()->with('error', 'Επέλεξε τουλάχιστον ένα source διαφορετικό από τον στόχο.');
        }

        DB::transaction(function() use ($targetId, $sources) {
            // 1) Upsert all (mcc,mnc) pairs from sources into target by unique (mcc,mnc)
            $rows = DB::table('network_mncs')
                ->whereIn('network_id', $sources)
                ->get(['mcc','mnc','mcc_mnc']);

            if ($rows->count() > 0) {
                $bulk = [];
                $now = now();
                foreach ($rows as $r) {
                    $bulk[] = [
                        'network_id' => $targetId,
                        'mcc'        => (string)$r->mcc,
                        'mnc'        => (string)$r->mnc,
                        'mcc_mnc'    => (string)$r->mcc_mnc,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
                // Unique key is (mcc,mnc); move ownership to target on conflict
                DB::table('network_mncs')->upsert(
                    $bulk,
                    ['mcc','mnc'],
                    ['network_id','updated_at','mcc_mnc']
                );
            }

            // 2) Remove any leftover rows for sources
            DB::table('network_mncs')->whereIn('network_id', $sources)->delete();

            // 3) Delete source networks
            DB::table('networks')->whereIn('id', $sources)->delete();
        });

        return back()->with('status', 'Συγχώνευση ολοκληρώθηκε.')
                     ->with('log', [
                         'target'  => $targetId,
                         'sources' => $sources,
                         'note'    => (string)($validated['reason'] ?? ''),
                     ]);
    }
}
PHP

# 2) Blade view
V=resources/views/networks/duplicates.blade.php
b "$V"; mkdir -p "$(dirname "$V")"
cat > "$V" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Network Duplicates</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-8">
    @if (session('error'))
      <div class="p-3 rounded bg-red-100 text-red-800">{{ session('error') }}</div>
    @endif
    @if (session('status'))
      <div class="p-3 rounded bg-green-100 text-green-800">{{ session('status') }}</div>
    @endif
    @if (session('log'))
      <pre class="p-3 rounded bg-gray-100 text-xs overflow-auto">{{ json_encode(session('log'), JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE) }}</pre>
    @endif

    <div class="space-y-6">
      <h3 class="text-lg font-semibold">1) Duplicates by MCC+MNC</h3>
      @forelse ($dupByPair as $grp)
        @php $nets = json_decode($grp->nets ?? '[]', true) ?: []; @endphp
        <div class="border rounded p-3 bg-white">
          <div class="mb-2">
            <span class="font-mono text-sm px-2 py-1 bg-gray-100 rounded">MCC {{ $grp->mcc }} / MNC {{ $grp->mnc }}</span>
            <span class="ml-2 text-sm text-gray-500">({{ $grp->c }} entries)</span>
          </div>

          <form method="POST" action="{{ route('networks.duplicates.merge') }}" class="space-y-2">
            @csrf
            <input type="hidden" name="reason" value="merge-by-mcc-mnc {{ $grp->mcc }}-{{ $grp->mnc }}">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
              @foreach ($nets as $i => $n)
                <label class="flex items-center gap-2 border rounded p-2">
                  <input type="radio" name="target_id" value="{{ $n['id'] }}" {{ $i===0 ? 'checked' : '' }}>
                  <input type="checkbox" name="source_ids[]" value="{{ $n['id'] }}" {{ $i!==0 ? 'checked' : '' }}>
                  <span class="text-sm">
                    <span class="font-semibold">{{ $n['name'] }}</span>
                    <span class="text-gray-500">— {{ $n['id'] }}</span>
                    <span class="ml-1 text-gray-400">[{{ $n['country'] ?? '' }}]</span>
                  </span>
                </label>
              @endforeach
            </div>
            <div class="text-right">
              <button class="px-3 py-1 rounded bg-blue-600 text-white">Merge into selected</button>
            </div>
          </form>
        </div>
      @empty
        <div class="text-sm text-gray-500">No duplicates by MCC/MNC detected.</div>
      @endforelse
    </div>

    <div class="space-y-6">
      <h3 class="text-lg font-semibold">2) Duplicates by Country + Name</h3>
      @forelse ($dupByName as $grp)
        @php $nets = json_decode($grp->nets ?? '[]', true) ?: []; @endphp
        <div class="border rounded p-3 bg-white">
          <div class="mb-2">
            <span class="font-mono text-sm px-2 py-1 bg-gray-100 rounded">{{ $grp->country }}</span>
            <span class="ml-2 text-sm text-gray-500">name: “{{ $grp->lname }}” ({{ $grp->c }} entries)</span>
          </div>

          <form method="POST" action="{{ route('networks.duplicates.merge') }}" class="space-y-2">
            @csrf
            <input type="hidden" name="reason" value="merge-by-name country={{ $grp->country }} name={{ $grp->lname }}">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
              @foreach ($nets as $i => $n)
                <label class="flex items-center gap-2 border rounded p-2">
                  <input type="radio" name="target_id" value="{{ $n['id'] }}" {{ $i===0 ? 'checked' : '' }}>
                  <input type="checkbox" name="source_ids[]" value="{{ $n['id'] }}" {{ $i!==0 ? 'checked' : '' }}>
                  <span class="text-sm">
                    <span class="font-semibold">{{ $n['name'] }}</span>
                    <span class="text-gray-500">— {{ $n['id'] }}</span>
                  </span>
                </label>
              @endforeach
            </div>
            <div class="text-right">
              <button class="px-3 py-1 rounded bg-blue-600 text-white">Merge into selected</button>
            </div>
          </form>
        </div>
      @empty
        <div class="text-sm text-gray-500">No duplicates by Country+Name detected.</div>
      @endforelse
    </div>
  </div>
</x-app-layout>
BLADE

# 3) Routes (admin-only). Replace any older duplicates routes with our pair.
R=routes/web.php
b "$R"
php -r '
$R="routes/web.php"; $c=file_get_contents($R);
$c=preg_replace("~\\n\\s*Route::get\\([\"\\'\\\"]networks/duplicates[\"\\'\\\"][\\s\\S]*?;\\n~","\\n",$c, -1);
$c=preg_replace("~\\n\\s*Route::post\\([\"\\'\\\"]networks/duplicates/merge[\"\\'\\\"][\\s\\S]*?;\\n~","\\n",$c, -1);
file_put_contents($R,$c);
'
php -r '
$R="routes/web.php"; $c=file_get_contents($R);
use App\\Http\\Controllers\\NetworkDedupController;
if(strpos($c,"use App\\\\Http\\\\Controllers\\\\NetworkDedupController;")===false){
  $c=preg_replace("/^<\\?php\\n/","<?php\nuse App\\\\Http\\\\Controllers\\\\NetworkDedupController;\n",$c,1);
}
if(strpos($c,"networks/duplicates")===false){
  $c.="\nRoute::middleware([\"auth\",\"admin\"])"
     ."\n  ->group(function(){"
     ."\n    Route::get(\"networks/duplicates\", [NetworkDedupController::class, \"index\"])"
     ."\n      ->name(\"networks.duplicates.index\");"
     ."\n    Route::post(\"networks/duplicates/merge\", [NetworkDedupController::class, \"merge\"])"
     ."\n      ->name(\"networks.duplicates.merge\");"
     ."\n  });\n";
}
file_put_contents($R,$c);
'

# 4) Lint & cache inside container (NOTE: use double-quotes so $DC expands)
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l app/Http/Controllers/NetworkDedupController.php
  php -l routes/web.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  echo "==> Routes grep:"
  php artisan route:list | grep -n "networks\.duplicates" || true
'

echo "==> Step8 done. Open /networks/duplicates"
