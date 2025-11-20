<?php
namespace App\Http\Controllers\Api;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;

class CountrySearchController extends Controller {
    public function __invoke(Request $request) {
        $q = trim((string)$request->query('q',''));
        $limit = (int)($request->query('limit', 20));
        if ($limit < 1 || $limit > 50) $limit = 20;

        if ($q === '') return response()->json([]);

        // ilike for Postgres (case-insensitive)
        $rows = DB::table('countries')
            ->select('id','name')
            ->where('name','ilike',"%{$q}%")
            ->orderBy('name')
            ->limit($limit)
            ->get();

        $ids = $rows->pluck('id')->all();
        $mccs = DB::table('country_mccs')
            ->select('country_id','mcc')
            ->whereIn('country_id',$ids)
            ->orderBy('mcc')
            ->get()
            ->groupBy('country_id')
            ->map(fn($g)=>$g->pluck('mcc')->values()->all());

        $out = [];
        foreach ($rows as $r) {
            $out[] = ['id'=>$r->id,'name'=>$r->name,'mccs'=>$mccs[$r->id] ?? []];
        }
        return response()->json($out);
    }
}
