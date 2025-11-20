<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class NetworkDedupController extends Controller
{
    public function index(Request $request)
    {
        // Duplicates by MCC+MNC
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

        // Duplicates by Country + lower(name)
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
            'target_id'    => ['required','integer','exists:networks,id'],
            'source_ids'   => ['required','array','min:1'],
            'source_ids.*' => ['integer','different:target_id','exists:networks,id'],
            'reason'       => ['nullable','string','max:500'],
        ]);

        $targetId = (int)$validated['target_id'];
        $sources  = array_values(array_unique(array_map('intval', $validated['source_ids'])));
        $sources  = array_values(array_diff($sources, [$targetId]));
        if (!$sources) {
            return back()->with('error','Επίλεξε τουλάχιστον ένα source διαφορετικό από τον στόχο.');
        }

        DB::transaction(function() use ($targetId, $sources) {
            // Move all (mcc,mnc) pairs to target (unique on (mcc,mnc))
            $rows = DB::table('network_mncs')
                ->whereIn('network_id', $sources)
                ->get(['mcc','mnc','mcc_mnc']);

            if ($rows->count()) {
                $now = now();
                $bulk = [];
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
                DB::table('network_mncs')->upsert(
                    $bulk,
                    ['mcc','mnc'],
                    ['network_id','updated_at','mcc_mnc']
                );
            }

            // Clean up sources
            DB::table('network_mncs')->whereIn('network_id', $sources)->delete();
            DB::table('networks')->whereIn('id', $sources)->delete();
        });

        return back()->with('status','Συγχώνευση ολοκληρώθηκε.')
                     ->with('log', [
                        'target'  => $targetId,
                        'sources' => $sources,
                        'note'    => (string)($validated['reason'] ?? ''),
                     ]);
    }
}
