<?php
namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CountryLookupController extends Controller
{
    public function search(Request $request)
    {
        $q = mb_strtolower(trim((string)$request->query('q','')));
        $limit = (int)($request->query('limit', 20));
        $rows = DB::table('countries')
            ->when($q !== '', fn($qq)=>$qq->whereRaw('lower(name) like ?', ['%'.$q.'%']))
            ->orderBy('name')
            ->limit($limit)
            ->get(['id','name']);

        // attach MCCs for each country (array of strings)
        $ids = $rows->pluck('id')->all();
        $mccMap = DB::table('country_mccs')
            ->whereIn('country_id', $ids)
            ->orderBy('mcc')
            ->get(['country_id','mcc'])
            ->groupBy('country_id')
            ->map(fn($g)=>$g->pluck('mcc')->values()->all());

        $out = $rows->map(function($r) use ($mccMap){
            return [
                'id'   => $r->id,
                'name' => $r->name,
                'mccs' => $mccMap[$r->id] ?? [],
            ];
        });

        return response()->json($out);
    }

    public function mccs($countryId)
    {
        $mccs = DB::table('country_mccs')
            ->where('country_id', (int)$countryId)
            ->orderBy('mcc')
            ->pluck('mcc')
            ->values()
            ->all();

        return response()->json(['country_id' => (int)$countryId, 'mccs' => $mccs]);
    }
}
