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
                    DB::raw("string_agg(DISTINCT mcc::text, ',' ORDER BY mcc::text) as mccs"),
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
            ->select('network_id', DB::raw("string_agg(DISTINCT mcc::text, ',' ORDER BY mcc::text) as mccs"))
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
