<?php
namespace App\Http\Controllers\Api;

use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;
use App\Models\Country;

class CountryMccsController extends Controller {
    public function __invoke(Country $country) {
        $mccs = DB::table('country_mccs')
            ->where('country_id',$country->id)
            ->orderBy('mcc')
            ->pluck('mcc')->values()->all();
        return response()->json(['mccs'=>$mccs]);
    }
}
