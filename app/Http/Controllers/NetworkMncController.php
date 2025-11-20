<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\Network;

class NetworkMncController extends Controller {
    public function store(Request $request, Network $network){
        $mcc = trim((string)$request->input('mcc',''));
        $mnc = trim((string)$request->input('mnc',''));
        $log = [];

        if (!preg_match('/^\d{3}$/', $mcc)) {
            return back()->with('error','MCC must be exactly 3 digits.');
        }
        if (!preg_match('/^\d{1,5}$/', $mnc)) {
            return back()->with('error','MNC must be 1-5 digits.');
        }

        // MCC must belong to network's country
        $allowed = DB::table('country_mccs')->where('country_id', $network->country_id)->pluck('mcc')->all();
        if (!in_array($mcc, $allowed, true)) {
            $log[] = "Rejected: MCC $mcc is not assigned to {$network->country->name}.";
            return back()->with('error', "MCC $mcc does not belong to this network's country.")->with('log',$log);
        }

        // Unique index (mcc,mnc) is global; block stealing from other network
        $existing = DB::table('network_mncs')->where('mcc',$mcc)->where('mnc',$mnc)->first();
        if ($existing) {
            if ((int)$existing->network_id === (int)$network->id) {
                return back()->with('status','Nothing to change. Already exists.');
            }
            $log[] = "Duplicate: $mcc-$mnc already linked to network_id={$existing->network_id}.";
            return back()->with('error','Duplicate MCC+MNC exists on another network.')->with('log',$log);
        }

        DB::table('network_mncs')->insert([
            'network_id' => $network->id,
            'mcc'        => $mcc,
            'mnc'        => $mnc,
            'mcc_mnc'    => $mcc.$mnc,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return back()->with('status','MNC added.');
    }

    public function destroy(Network $network, string $mcc, string $mnc){
        DB::table('network_mncs')->where('network_id',$network->id)->where('mcc',$mcc)->where('mnc',$mnc)->delete();
        return back()->with('status','MNC removed.');
    }
}
