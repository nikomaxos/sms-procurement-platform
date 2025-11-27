#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"

CTRL="${PROJECT_ROOT}/app/Http/Controllers/NetworksController.php"
VIEW="${PROJECT_ROOT}/resources/views/networks/index.blade.php"

BACKUP_DIR="${PROJECT_ROOT}/backup_networks_fix_$(date +%F_%H-%M-%S)"
echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

if [ -f "$CTRL" ]; then cp "$CTRL" "$BACKUP_DIR/NetworksController.php"; fi
if [ -f "$VIEW" ]; then cp "$VIEW" "$BACKUP_DIR/networks_index.blade.php"; fi

echo "==> Rewriting NetworksController.php"
cat > "$CTRL" << 'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\Country;
use App\Models\Network;
use App\Models\NetworkMeta;
use App\Models\NetworkMnc;
use App\Support\MccMncNormalizer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class NetworksController extends Controller
{
    public function index(Request $request)
    {
        $q         = trim((string) $request->query('q', ''));
        $countryId = $request->query('country_id');
        $perPage   = (int) $request->query('per_page', 20);

        if ($perPage < 5) {
            $perPage = 5;
        }
        if ($perPage > 200) {
            $perPage = 200;
        }

        $query = Network::query()
            ->with('country')
            ->withCount('mncs')
            ->orderBy('name');

        if ($q !== '') {
            $query->where('name', 'ilike', '%' . $q . '%');
        }

        if (!empty($countryId)) {
            $query->where('country_id', $countryId);
        }

        // CSV export
        if ($request->query('export') === 'csv') {
            $rows = $query->get(['id', 'country_id', 'name']);

            $map = DB::table('network_mncs')
                ->select([
                    'network_id',
                    DB::raw("string_agg(DISTINCT mcc::text, ',' ORDER BY mcc::text) as mccs"),
                    DB::raw("string_agg((mcc::text||'-'||mnc::text), ',' ORDER BY mcc,mnc) as pairs"),
                    DB::raw('count(*) as mnc_count'),
                ])
                ->whereIn('network_id', $rows->pluck('id'))
                ->groupBy('network_id')
                ->get()
                ->keyBy('network_id');

            $countries = DB::table('countries')
                ->whereIn('id', $rows->pluck('country_id'))
                ->pluck('name', 'id');

            $filename = 'networks_export_' . date('Ymd_His') . '.csv';

            return response()->streamDownload(function () use ($rows, $map, $countries) {
                $out = fopen('php://output', 'w');
                fputcsv($out, ['Network ID', 'Name', 'Country', 'MCCs', 'MNC count', 'MCC-MNC pairs']);

                foreach ($rows as $r) {
                    $a = $map[$r->id] ?? null;
                    fputcsv($out, [
                        $r->id,
                        $r->name,
                        $countries[$r->country_id] ?? '',
                        $a->mccs ?? '',
                        $a->mnc_count ?? 0,
                        $a->pairs ?? '',
                    ]);
                }

                fclose($out);
            }, $filename, [
                'Content-Type'  => 'text/csv',
                'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
            ]);
        }

        $networks = $query->paginate($perPage)->appends($request->query());

        $ids = $networks->getCollection()->pluck('id');
        $mccsMap = DB::table('network_mncs')
            ->select('network_id', DB::raw("string_agg(DISTINCT mcc::text, ',' ORDER BY mcc::text) as mccs"))
            ->whereIn('network_id', $ids)
            ->groupBy('network_id')
            ->pluck('mccs', 'network_id');

        $filters = [
            'q'            => $q,
            'country_id'   => $countryId,
            'country_name' => $countryId ? (DB::table('countries')->where('id', $countryId)->value('name') ?? '') : '',
            'per_page'     => $perPage,
        ];

        $countries = Country::orderBy('name')->get();

        return view('networks.index', [
            'networks'  => $networks,
            'mccsMap'   => $mccsMap,
            'filters'   => $filters,
            'countries' => $countries,
        ]);
    }

    public function create()
    {
        $network   = new Network();
        $countries = Country::orderBy('name')->get();

        return view('networks.create', compact('network', 'countries'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'country_id'      => 'required|integer|exists:countries,id',
            'name'            => 'required|string|max:255',
            'notes'           => 'nullable|string',
            'non_operational' => 'nullable',
            'mncs'            => 'array',
            'mncs.*.mcc'      => 'nullable|string',
            // ENFORCE: 2 or 3 digits only
            'mncs.*.mnc'      => ['nullable', 'regex:/^\d{2,3}$/'],
        ]);

        $network = new Network();
        $network->country_id = (int) $data['country_id'];
        $network->name       = $data['name'];

        if (schema_has_column('networks', 'lower_name')) {
            $network->lower_name = Str::lower($data['name']);
        }

        $network->save();

        $notes = isset($data['notes']) ? trim((string) $data['notes']) : '';
        $nonOperational = $request->boolean('non_operational');

        if ($notes !== '' || $nonOperational) {
            $meta = NetworkMeta::firstOrNew(['network_id' => $network->id]);
            $meta->non_operational = $nonOperational;
            $meta->notes           = $notes !== '' ? $notes : null;
            $meta->save();
        }

        $this->syncMncs($network, $data['mncs'] ?? []);

        return redirect()
            ->route('networks.edit', $network->id)
            ->with('status', 'Network created.');
    }

    public function edit(Network $network)
    {
        // country.mccs preloaded for readonly/default MCC in Blade
        $network->load('country.mccs', 'mncs', 'meta');
        $countries = Country::orderBy('name')->get();

        return view('networks.edit', compact('network', 'countries'));
    }

    public function update(Request $request, Network $network)
    {
        $data = $request->validate([
            'country_id'      => 'required|integer|exists:countries,id',
            'name'            => 'required|string|max:255',
            'notes'           => 'nullable|string',
            'non_operational' => 'nullable',
            'mncs'            => 'array',
            'mncs.*.mcc'      => 'nullable|string',
            // ENFORCE: 2 or 3 digits only
            'mncs.*.mnc'      => ['nullable', 'regex:/^\d{2,3}$/'],
        ]);

        $network->country_id = (int) $data['country_id'];
        $network->name       = $data['name'];

        if (schema_has_column('networks', 'lower_name')) {
            $network->lower_name = Str::lower($data['name']);
        }

        $network->save();

        // Extra safety: ensure country_id really persisted at DB level
        DB::table('networks')
            ->where('id', $network->id)
            ->update([
                'country_id' => (int) $data['country_id'],
            ]);

        $notes = isset($data['notes']) ? trim((string) $data['notes']) : '';
        $nonOperational = $request->boolean('non_operational');

        $meta = NetworkMeta::firstOrNew(['network_id' => $network->id]);
        $meta->non_operational = $nonOperational;
        $meta->notes           = $notes !== '' ? $notes : null;

        if ($notes === '' && !$nonOperational && $meta->exists) {
            $meta->notes = null;
        }

        $meta->save();

        $this->syncMncs($network, $data['mncs'] ?? []);

        return back()->with('status', 'Network saved.');
    }

    /**
     * Sync MCC/MNC rows for a network from mncs[n][mcc], mncs[n][mnc].
     * Extra guard: MCC must be 3 digits, MNC must be 2–3 digits.
     */
    protected function syncMncs(Network $network, ?array $mncs): void
    {
        if (!is_array($mncs)) {
            $mncs = [];
        }

        $normalized = [];

        foreach ($mncs as $row) {
            if (!is_array($row)) {
                continue;
            }

            $mcc = isset($row['mcc']) ? preg_replace('/\D/', '', (string) $row['mcc']) : '';
            $mnc = isset($row['mnc']) ? preg_replace('/\D/', '', (string) $row['mnc']) : '';

            if ($mcc === '' || $mnc === '') {
                continue;
            }

            // ENFORCE: MCC exactly 3 digits; MNC 2–3 digits
            if (strlen($mcc) !== 3) {
                continue;
            }
            if (strlen($mnc) < 2 || strlen($mnc) > 3) {
                continue;
            }

            $mcc = str_pad($mcc, 3, '0', STR_PAD_LEFT);
            $mncKey = str_pad($mnc, 3, '0', STR_PAD_LEFT);

            $key = $mcc . '-' . $mncKey;

            $normalized[$key] = [
                'mcc' => (int) $mcc,
                'mnc' => (int) $mnc,
            ];
        }

        // Friendly check for global MCC/MNC uniqueness across networks
        if (!empty($normalized)) {
            $conflicts = DB::table('network_mncs as nm')
                ->join('networks as n', 'n.id', '=', 'nm.network_id')
                ->leftJoin('countries as c', 'c.id', '=', 'n.country_id')
                ->where('nm.network_id', '!=', $network->id)
                ->where(function ($q) use ($normalized) {
                    foreach ($normalized as $row) {
                        $q->orWhere(function ($sub) use ($row) {
                            $sub->where('nm.mcc', $row['mcc'])
                                ->where('nm.mnc', $row['mnc']);
                        });
                    }
                })
                ->select(
                    'nm.mcc',
                    'nm.mnc',
                    'nm.network_id',
                    'n.name as network_name',
                    'c.name as country_name'
                )
                ->get();

            if ($conflicts->isNotEmpty()) {
                $messages = [];

                foreach ($conflicts as $conflict) {
                    $mccStr = str_pad((string) $conflict->mcc, 3, '0', STR_PAD_LEFT);
                    $mncStr = str_pad((string) $conflict->mnc, 3, '0', STR_PAD_LEFT);

                    $labelParts = [];
                    if (!empty($conflict->country_name)) {
                        $labelParts[] = $conflict->country_name;
                    }
                    if (!empty($conflict->network_name)) {
                        $labelParts[] = $conflict->network_name;
                    }
                    $label = implode(' - ', $labelParts);

                    $messages[] = sprintf(
                        'MCC/MNC %s/%s is already assigned to %s (ID %d). Remove it there first if you want to move it.',
                        $mccStr,
                        $mncStr,
                        $label !== '' ? $label : ('network ID ' . $conflict->network_id),
                        $conflict->network_id
                    );
                }

                throw \Illuminate\Validation\ValidationException::withMessages([
                    'mncs' => $messages,
                ]);
            }
        }

        $existing = NetworkMnc::where('network_id', $network->id)->get();
        $existingByKey = [];

        foreach ($existing as $m) {
            $mcc = str_pad((string) $m->mcc, 3, '0', STR_PAD_LEFT);
            $mncKey = str_pad((string) $m->mnc, 3, '0', STR_PAD_LEFT);
            $existingByKey[$mcc . '-' . $mncKey] = $m;
        }

        // Delete removed
        foreach ($existingByKey as $key => $m) {
            if (!array_key_exists($key, $normalized)) {
                $m->delete();
            }
        }

        $userId = optional(auth()->user())->id;

        // Create new or update existing
        foreach ($normalized as $key => $row) {
            if (isset($existingByKey[$key])) {
                $m = $existingByKey[$key];
                if ($userId) {
                    $m->updated_by_user_id = $userId;
                }
                $m->updated_by_source = 'networks.edit';
                $m->save();
                continue;
            }

            $mccInt = $row['mcc'];
            $mncInt = $row['mnc'];
            $raw = sprintf('%03d%03d', $mccInt, $mncInt);

            $mccMnc = class_exists(MccMncNormalizer::class)
                ? MccMncNormalizer::normalize($raw)
                : $raw;

            $m = new NetworkMnc();
            $m->network_id = $network->id;
            $m->mcc = $mccInt;
            $m->mnc = $mncInt;
            $m->mcc_mnc = $mccMnc;
            $m->marked_for_deletion = false;

            if ($userId) {
                $m->created_by_user_id = $userId;
                $m->updated_by_user_id = $userId;
            }

            $m->created_by_source = 'networks.edit';
            $m->updated_by_source = 'networks.edit';

            $m->save();
        }
    }
}

/**
 * Tiny helper: check if a column exists (Postgres-safe).
 */
if (!function_exists('schema_has_column')) {
    function schema_has_column(string $table, string $column): bool
    {
        try {
            return \Illuminate\Support\Facades\Schema::hasColumn($table, $column);
        } catch (\Throwable $e) {
            return false;
        }
    }
}
PHP

chmod 644 "$CTRL"

echo "==> Rewriting networks index view"
mkdir -p "$(dirname "$VIEW")"
cat > "$VIEW" << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Networks
        </h2>
    </x-slot>

    @php
        $q         = $filters['q'] ?? '';
        $countryId = $filters['country_id'] ?? null;
        $perPage   = $filters['per_page'] ?? 20;
    @endphp

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
        @includeIf('partials.flash_log')

        {{-- Filters --}}
        <div class="bg-white p-4 rounded-lg shadow">
            <form method="GET" action="{{ route('networks.index') }}" class="grid grid-cols-1 md:grid-cols-3 gap-4 items-end">
                <div>
                    <label for="filter_q" class="block text-sm font-medium text-gray-700">
                        Name
                    </label>
                    <input
                        type="text"
                        id="filter_q"
                        name="q"
                        value="{{ $q }}"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        placeholder="Search by network name"
                    >
                </div>

                <div>
                    <label for="filter_country_id" class="block text-sm font-medium text-gray-700">
                        Country
                    </label>
                    <select
                        id="filter_country_id"
                        name="country_id"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                    >
                        <option value="">All</option>
                        @foreach($countries as $country)
                            <option value="{{ $country->id }}" @selected((string) $countryId === (string) $country->id)>
                                {{ $country->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                <div class="flex flex-wrap gap-2 justify-start md:justify-end">
                    <button
                        type="submit"
                        class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:ring-offset-1"
                    >
                        Apply filters
                    </button>
                    <a
                        href="{{ route('networks.index') }}"
                        class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                    >
                        Reset
                    </a>
                    <a
                        href="{{ route('networks.index', array_merge(request()->except('page'), ['export' => 'csv'])) }}"
                        class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                    >
                        Export CSV
                    </a>
                </div>
            </form>
        </div>

        {{-- Table + Create button --}}
        <div class="bg-white p-4 rounded-lg shadow">
            <div class="flex items-center justify-between mb-3">
                <h3 class="text-md font-semibold text-gray-800">
                    Results
                </h3>
                <a
                    href="{{ route('networks.create') }}"
                    class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-semibold rounded-md shadow-sm text-white bg-green-500 hover:bg-green-600"
                >
                    Create Network
                </a>
            </div>

            <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                    <thead class="bg-gray-50">
                        <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                            <th class="px-4 py-3">Name</th>
                            <th class="px-4 py-3">Country</th>
                            <th class="px-4 py-3">MCCs</th>
                            <th class="px-4 py-3 text-right">MNC count</th>
                            <th class="px-4 py-3 text-right">Actions</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200">
                        @forelse($networks as $network)
                            <tr>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    {{ $network->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    {{ optional($network->country)->name ?? '—' }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    @php
                                        $mccs = $mccsMap[$network->id] ?? null;
                                    @endphp
                                    @if($mccs)
                                        @foreach(explode(',', $mccs) as $mcc)
                                            <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-gray-100 text-xs font-medium text-gray-800 mr-1">
                                                {{ $mcc }}
                                            </span>
                                        @endforeach
                                    @else
                                        <span class="text-xs text-gray-400">—</span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-right text-xs">
                                    {{ $network->mncs_count ?? 0 }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-right text-xs">
                                    <a
                                        href="{{ route('networks.edit', $network) }}"
                                        class="inline-flex items-center px-2 py-1 border border-gray-300 rounded-md bg-white text-gray-700 hover:bg-gray-50"
                                    >
                                        Edit
                                    </a>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="5" class="px-4 py-4 text-center text-sm text-gray-500">
                                    No networks found.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{-- Pagination + per-page selector --}}
            <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3 mt-3">
                <div>
                    {{ $networks->links() }}
                </div>
                <div class="flex items-center gap-2 text-xs">
                    <span class="text-gray-600">Results per page:</span>
                    <form method="GET" action="{{ route('networks.index') }}">
                        <input type="hidden" name="q" value="{{ $q }}">
                        <input type="hidden" name="country_id" value="{{ $countryId }}">
                        <select
                            name="per_page"
                            class="rounded-md border-gray-300 text-xs shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                            onchange="this.form.submit()"
                        >
                            @foreach([10, 25, 50, 100, 200] as $size)
                                <option value="{{ $size }}" @selected((int) $perPage === (int) $size)>{{ $size }}</option>
                            @endforeach
                        </select>
                    </form>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
BLADE

chmod 644 "$VIEW"

echo "==> Done. Now open /networks in your browser."
