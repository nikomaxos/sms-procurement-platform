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

        return view('networks.index', [
            'networks' => $networks,
            'mccsMap'  => $mccsMap,
            'filters'  => $filters,
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
            'mncs.*.mnc'      => 'nullable|string',
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
        // KEY CHANGE: also eager-load country.mccs so Blade can get the default MCC
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
            'mncs.*.mnc'      => 'nullable|string',
        ]);

        $network->country_id = (int) $data['country_id'];
        $network->name       = $data['name'];

        if (schema_has_column('networks', 'lower_name')) {
            $network->lower_name = Str::lower($data['name']);
        }

        $network->save();

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

            $mcc = str_pad($mcc, 3, '0', STR_PAD_LEFT);
            $mncKey = str_pad($mnc, 3, '0', STR_PAD_LEFT);

            $key = $mcc . '-' . $mncKey;

            $normalized[$key] = [
                'mcc' => (int) $mcc,
                'mnc' => (int) $mnc,
            ];
        }

        $existing = NetworkMnc::where('network_id', $network->id)->get();
        $existingByKey = [];

        foreach ($existing as $m) {
            $mcc = str_pad((string) $m->mcc, 3, '0', STR_PAD_LEFT);
            $mncKey = str_pad((string) $m->mnc, 3, '0', STR_PAD_LEFT);
            $existingByKey[$mcc . '-' . $mncKey] = $m;
        }

        foreach ($existingByKey as $key => $m) {
            if (!array_key_exists($key, $normalized)) {
                $m->delete();
            }
        }

        $userId = optional(auth()->user())->id;

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
