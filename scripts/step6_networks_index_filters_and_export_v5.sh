#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step6 v5: Restore NetworksController + filters + CSV export (atomic)"

CTRL=app/Http/Controllers/NetworksController.php
VIEW=resources/views/networks/index.blade.php

# 1) Backup damaged files (if any)
b "$CTRL"
b "$VIEW"

# 2) Write a **known-good** NetworksController with index/create/store/edit/update
cat > "$CTRL" <<'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use App\Models\Network;
use App\Models\Country;

class NetworksController extends Controller
{
    public function index(Request $request)
    {
        $q         = trim((string) $request->query('q',''));
        $countryId = $request->query('country_id');
        $perPage   = (int) $request->query('per_page', 20);
        if ($perPage < 5)  { $perPage = 5; }
        if ($perPage > 100){ $perPage = 100; }

        $query = Network::query()
            ->with('country')
            ->withCount('mncs')
            ->orderBy('name');

        if ($q !== '') {
            // Postgres case-insensitive search
            $query->where('name','ilike', "%{$q}%");
        }
        if (!empty($countryId)) {
            $query->where('country_id', $countryId);
        }

        // CSV export (respects filters)
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

        // light MCC aggregation for current page
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

    public function create()
    {
        $network = new Network();
        return view('networks.create', compact('network'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'country_id' => 'required|integer|exists:countries,id',
            'name'       => 'required|string|max:255',
        ]);

        $network = new Network();
        $network->country_id = (int)$data['country_id'];
        $network->name       = $data['name'];
        // keep lower_name consistent with unique index
        if (schema_has_column('networks','lower_name')) {
            $network->lower_name = Str::lower($data['name']);
        }
        $network->save();

        return redirect()->route('networks.edit', $network->id)->with('status','Network created.');
    }

    public function edit(Network $network)
    {
        $network->load('country','mncs');
        return view('networks.edit', compact('network'));
    }

    public function update(Request $request, Network $network)
    {
        $data = $request->validate([
            'country_id' => 'required|integer|exists:countries,id',
            'name'       => 'required|string|max:255',
        ]);

        $network->country_id = (int)$data['country_id'];
        $network->name       = $data['name'];
        if (schema_has_column('networks','lower_name')) {
            $network->lower_name = Str::lower($data['name']);
        }
        $network->save();

        return back()->with('status','Network saved.');
    }
}

/**
 * Tiny helper: check if a column exists (Postgres-safe).
 */
if (!function_exists('schema_has_column')) {
    function schema_has_column(string $table, string $column): bool {
        try {
            return \Illuminate\Support\Facades\Schema::hasColumn($table, $column);
        } catch (\Throwable $e) {
            return false;
        }
    }
}
PHP

# 3) Write the Networks index view with filters + typeahead + CSV export
cat > "$VIEW" <<'BLADE'
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
      try{
        const r = await fetch(`/api/countries/search?q=${encodeURIComponent(q)}&limit=20`);
        if(!r.ok){ box.classList.add('hidden'); return; }
        last = await r.json();
        show(last);
      }catch(_e){ box.classList.add('hidden'); }
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

# 4) Lint & warm caches; if lint fails, restore backups
if ! $DC exec -T app php -l "$CTRL" >/dev/null ; then
  echo "!! Lint failed — restoring controller backup"
  cp -a "$CTRL.bak.$ts" "$CTRL" 2>/dev/null || true
  $DC exec -T app php -l "$CTRL" || true
  exit 1
fi
if ! $DC exec -T app php -l "$VIEW" >/dev/null ; then
  echo "!! Lint failed — restoring view backup"
  cp -a "$VIEW.bak.$ts" "$VIEW" 2>/dev/null || true
  $DC exec -T app php -l "$VIEW" || true
  exit 1
fi

$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  php artisan route:list | grep -n "networks\.\(index\|edit\|store\|update\)" || true
'
echo "==> Step6 v5 done."
