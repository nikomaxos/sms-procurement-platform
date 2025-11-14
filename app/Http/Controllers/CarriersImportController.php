<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\CarrierImportService;

class CarriersImportController extends Controller
{
    public function run(Request $r, CarrierImportService $svc)
    {
        $source = (string) $r->input('source','itu');
        $fresh  = (bool) $r->boolean('fresh', false);
        $out = $svc->import($source, $fresh);
        if (!$out['ok']) {
            return back()->withErrors(['import'=>$out['msg']]);
        }
        return back()->with('status', sprintf(
            'Import OK: %s (countries +%d, networks +%d, mncs +%d)',
            $out['msg'], $out['createdCountries'], $out['createdNetworks'], $out['createdMncs']
        ));
    }
}
