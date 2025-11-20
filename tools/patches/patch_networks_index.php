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
            'Content-Type' => 'text/csv',
            'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
        ]);
    }

    $networks = $query->paginate($perPage)->appends($request->query());

    // MCCs for current page only (lightweight)
    $ids = $networks->getCollection()->pluck('id');
    $mccsMap = DB::table('network_mncs')
        ->select('network_id', DB::raw("string_agg(DISTINCT mcc::text, ',' ORDER BY mcc) as mccs"))
        ->whereIn('network_id', $ids)
        ->groupBy('network_id')
        ->pluck('mccs','network_id');

    $filters = [
        'q' => $q,
        'country_id' => $countryId,
        'country_name' => $countryId ? (DB::table('countries')->where('id',$countryId)->value('name') ?? '') : '',
        'per_page' => $perPage,
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
    // Append inside class, before final closing brace
    $c = preg_replace('/}\s*$/', $body . "\n}\n", $c, 1);
}
file_put_contents($F, $c);
echo "patched index()\n";
