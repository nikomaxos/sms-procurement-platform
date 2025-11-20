#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"; b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step6 v3: Networks index filters + CSV export + UI polish (with backup & restore)"

F=app/Http/Controllers/NetworksController.php
b "$F"
mkdir -p tools/patches

# ---- patcher that fully replaces/creates index() ----
cat > tools/patches/patch_networks_index_v3.php <<'PHP'
<?php
$F = 'app/Http/Controllers/NetworksController.php';
$c = file_get_contents($F);
if ($c === false) { fwrite(STDERR, "Cannot read $F\n"); exit(1); }

if (strpos($c, "use Illuminate\\Http\\Request;") === false) {
    $c = preg_replace(
        '/^<\?php\s+namespace App\\\\Http\\\\Controllers;/',
        "<?php\nnamespace App\\Http\\Controllers;\n\nuse Illuminate\\Http\\Request;\nuse Illuminate\\Support\\Facades\\DB;",
        $c, 1
    );
} elseif (strpos($c, "use Illuminate\\Support\\Facades\\DB;") === false) {
    $c = str_replace(
        "use Illuminate\\Http\\Request;",
        "use Illuminate\\Http\\Request;\nuse Illuminate\\Support\\Facades\\DB;",
        $c
    );
}

$methodRx = '/public\s+function\s+index\s*\([^)]*\)\s*\{[\s\S]*?\n\}\n/';
$body = <<<'PHPBODY'
public function index(Request $request)
{
    $q         = trim((string) $request->query('q',''));
    $countryId = $request->query('country_id');
    $perPage   = (int) $request->query('per_page', 20);
    if ($perPage < 5)  $perPage = 5;
    if ($perPage > 100) $perPage = 100;

    $query = \App\Models\Network::query()
        ->with('country')
        ->withCount('mncs')
        ->orderBy('name');

    if ($q !== '') {
        // Postgres case-insensitive match
        $query->where('name','ilike', "%{$q}%");
    }
    if (!empty($countryId)) {
        $query->where('country_id', $countryId);
    }

    // CSV export (respects active filters)
    if ($request->query('export') === 'csv') {
        $rows = $query->get(['id','country_id','name']);

        $map = DB::table('network_mncs')
            ->select([
                'network_id',
                DB::raw("string_agg(DISTINCT mcc::text, ',' ORDER BY mcc) as mccs"),
                DB::raw("string_agg((mcc::text||'-'||mnc::text), ',' ORDER BY mcc,mnc) as pairs"),
                DB::raw('count(*) as mnc_count')
            ])
            ->whereIn('network_id', $rows->pluck('id'))
            ->groupBy('network_id')
            ->get()
            ->keyBy('network_id');

        $countries = DB::table('countries')
            ->whereIn('id', $rows->pluck('country_id'))
            ->pluck('name','id');

        $filename = 'networks_export_'.date('Ymd_His').'.csv';
        return response()->streamDownload(function() use ($rows,$map,$countries){
            $out = fopen('php://output','w');
            fputcsv($out, ['Network ID','Name','Country','MCCs','MNC count','MCC-MNC pairs']);
            foreach ($rows as $r) {
                $a = $map[$r->id] ?? null;
                fputcsv($out, [
                    $r->id,
                    $r->name,
                    $countries[$r->country_id] ?? $r->country_id,
                    $a->mccs ?? '',
                    $a->mnc_count ?? 0,
                    $a->pairs ?? ''
                ]);
            }
            fclose($out);
        }, $filename, [
            'Content-Type'  => 'text/csv',
            'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
        ]);
    }

    $networks = $query->paginate($perPage)->appends($request->query());

    // MCCs for current page (light)
    $ids = $networks->getCollection()->pluck('id');
    $mccsMap = DB::table('network_mncs')
        ->select('network_id', DB::raw("string_agg(DISTINCT mcc::text, ',' ORDER BY mcc) as mccs"))
        ->whereIn('network_id', $ids)
        ->groupBy('network_id')
        ->pluck('mccs','network_id');

    $filters = [
        'q'            => $q,
        'country_id'   => $countryId,
        'country_name' => $countryId ? (DB::table('countries')->where('id',$countryId)->value('name') ?? '') : '',
        'per_page'     => $perPage,
    ];

    return view('networks.index', [
        'networks' => $networks,
        'mccsMap'  => $mccsMap,
        'filters'  => $filters,
    ]);
}
PHPBODY;

if (preg_match($methodRx, $c)) {
    $c = preg_replace($methodRx, $body . "\n", $c, 1);
} else {
    // Append method before final class closing brace
    $c = preg_replace('/}\s*$/', $body . "\n}\n", $c, 1);
}
file_put_contents($F, $c);
echo "patched index()\n";
PHP

# Execute patcher
$DC exec -T app php tools/patches/patch_networks_index_v3.php

# Lint controller; restore on error
if ! $DC exec -T app php -l "$F" >/dev/null ; then
  echo "!! Lint failed — restoring last backup"
  LAST_BAK="$(ls -t ${F}.bak.* 2>/dev/null | head -1 || true)"
  if [ -n "$LAST_BAK" ]; then cp -a "$LAST_BAK" "$F"; fi
  $DC exec -T app php -l "$F" || true
  exit 1
fi

# ---- Replace networks/index.blade.php with filters + typeahead + CSV button ----
V=resources/views/networks/index.blade.php
b "$V"
cat > "$V" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @includeIf('partials.flash_log')

    <form method="GET" action="{{ route('networks.index') }}" class="bg-white rounded shadow p-4 mb-4">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-3 items-end">
        <div class="md:col-span-2">
          <label class="block text-sm font-medium mb-1">Search name</label>
          <input class="border rounded w-full p-2" type="text" name="q" value="{{ $filters['q'] ?? '' }}" placeholder="e.g. Cosmote">
        </div>

        <div>
          <label class="block text-sm font-medium mb-1">Country</label>
          <div class="relative">
            <input id="fi_country" class="border rounded w-full p-2" type="text" autocomplete="off"
                   placeholder="Type to search..."
                   value="{{ $filters['country_name'] ?? '' }}">
            <input type="hidden" name="country_id" id="fi_country_id" value="{{ $filters['country_id'] ?? '' }}">
            <div id="fi_results" class="hidden absolute z-10 mt-1 w-full bg-white border rounded shadow max-h-64 overflow-auto"></div>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium mb-1">Per page</label>
          <select class="border rounded w-full p-2" name="per_page">
            @foreach([20,50,100] as $n)
              <option value="{{ $n }}" @selected(($filters['per_page'] ?? 20)==$n)>{{ $n }}</option>
            @endforeach
          </select>
        </div>
      </div>

      <div class="mt-3 flex flex-wrap gap-2">
        <button class="rounded bg-blue-600 text-white px-4 py-2" type="submit">Filter</button>
        <a class="rounded bg-gray-100 px-4 py-2 border" href="{{ route('networks.index') }}">Clear</a>
        <a class="rounded bg-gray-800 text-white px-4 py-2"
           href="{{ route('networks.index', array_merge(request()->query(), ['export' => 'csv'])) }}">
           Export CSV
        </a>
      </div>
    </form>

    <div class="bg-white rounded shadow overflow-x-auto">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="text-left px-4 py-2">Name</th>
            <th class="text-left px-4 py-2">Country</th>
            <th class="text-left px-4 py-2">MCCs</th>
            <th class="text-left px-4 py-2">MNCs</th>
            <th class="text-left px-4 py-2">Actions</th>
          </tr>
        </thead>
        <tbody>
          @foreach ($networks as $n)
            <tr class="border-t">
              <td class="px-4 py-2">{{ $n->name }}</td>
              <td class="px-4 py-2">{{ $n->country->name ?? $n->country_id }}</td>
              <td class="px-4 py-2">
                @php $mccs = isset($mccsMap[$n->id]) ? explode(",", $mccsMap[$n->id]) : []; @endphp
                @forelse($mccs as $m)
                  <span class="inline-block text-xs bg-gray-100 border rounded px-2 py-0.5 mr-1 mb-1">{{ $m }}</span>
                @empty
                  <span class="text-gray-400">—</span>
                @endforelse
              </td>
              <td class="px-4 py-2">{{ $n->mncs_count }}</td>
              <td class="px-4 py-2">
                <a class="text-blue-700 hover:underline" href="{{ route('networks.edit', $n->id) }}">Edit</a>
              </td>
            </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $networks->links() }}</div>
  </div>

  <script>
  (function(){
    const root = document;
    const box = root.getElementById('fi_results');
    const input = root.getElementById('fi_country');
    const hidden = root.getElementById('fi_country_id');
    if(!input || !box) return;

    const show = (rows)=>{
      box.innerHTML = '';
      if(!rows || !rows.length){ box.classList.add('hidden'); return; }
      rows.forEach(r=>{
        const d = document.createElement('div');
        const mcc = (r.mccs && r.mccs.length) ? ` (MCC: ${r.mccs.join(', ')})` : '';
        d.textContent = r.name + mcc;
        d.className = 'px-3 py-2 hover:bg-gray-50 cursor-pointer';
        d.addEventListener('click', ()=>{
          input.value = r.name;
          hidden.value = r.id;
          box.classList.add('hidden');
        });
        box.appendChild(d);
      });
      box.classList.remove('hidden');
    };

    let last = [];
    async function search(q){
      const r = await fetch(`/api/countries/search?q=${encodeURIComponent(q)}&limit=20`);
      if(!r.ok){ box.classList.add('hidden'); return; }
      last = await r.json();
      show(last);
    }

    input.addEventListener('input', e=>{
      const q = e.target.value.trim();
      if(!q){ box.classList.add('hidden'); hidden.value = ''; return; }
      search(q);
    });
    input.addEventListener('focus', ()=>{ if(last.length) box.classList.remove('hidden'); });
    document.addEventListener('click', e=>{ if(!box.contains(e.target) && e.target!==input) box.classList.add('hidden'); });
    input.addEventListener('keydown', e=>{ if(e.key==='Escape') box.classList.add('hidden'); });
  })();
  </script>
</x-app-layout>
BLADE

# ---- Warm caches + quick route check ----
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l app/Http/Controllers/NetworksController.php
  php -l resources/views/networks/index.blade.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  php artisan route:list | grep -n "networks\.\(index\|edit\|store\|update\)" || true
'
echo "==> Step6 v3 done."
