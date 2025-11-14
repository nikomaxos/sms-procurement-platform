<?php
namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use App\Models\Country;
use App\Models\Network;

class CarrierImportService {
    /**
     * @return array{ok:bool,msg:string,createdCountries:int,createdNetworks:int,createdMncs:int}
     */
    public function import(string $source, bool $fresh): array {
        $createdCountries=0; $createdNetworks=0; $createdMncs=0;

        if ($fresh) {
            DB::table('network_mncs')->truncate();
            DB::table('country_mccs')->truncate();
        }

        $urls = [
            'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
        ];
        $rows = [];
        foreach ($urls as $url) {
            try {
                $res = Http::timeout(30)->get($url);
                if ($res->successful() && is_array($res->json())) {
                    $rows = array_merge($rows, $res->json());
                }
            } catch (\Throwable $e) {}
        }
        if (!$rows) return ['ok'=>false,'msg'=>'No data fetched','createdCountries'=>0,'createdNetworks'=>0,'createdMncs'=>0];

        DB::transaction(function () use ($rows, &$createdCountries, &$createdNetworks, &$createdMncs) {
            foreach ($rows as $r) {
                $mcc = (string)($r['mcc'] ?? $r['MCC'] ?? '');
                $mnc = (string)($r['mnc'] ?? $r['MNC'] ?? '');
                $cname = trim((string)($r['country'] ?? $r['country_name'] ?? $r['countryName'] ?? ''));
                $iso2  = $r['iso'] ?? $r['iso2'] ?? $r['country_code'] ?? null;
                $netName = trim((string)($r['brand'] ?? $r['operator'] ?? $r['network'] ?? ''));
                if ($mcc==='' || $mnc==='' || $cname==='' || $netName==='') continue;

                $country = Country::firstOrCreate(
                    ['name'=>$cname],
                    ['iso2'=> is_string($iso2) ? strtolower(substr($iso2,0,2)) : null]
                );
                if ($country->wasRecentlyCreated) $createdCountries++;

                // country_mccs
                if (!DB::table('country_mccs')->where(['country_id'=>$country->id,'mcc'=>$mcc])->exists()) {
                    DB::table('country_mccs')->insert(['country_id'=>$country->id,'mcc'=>$mcc,'created_at'=>now(),'updated_at'=>now()]);
                }

                // networks
                $network = Network::firstOrCreate(['name'=>$netName,'country_id'=>$country->id],[]);
                if ($network->wasRecentlyCreated) $createdNetworks++;

                // network_mncs
                if (!DB::table('network_mncs')->where(['network_id'=>$network->id,'mcc'=>$mcc,'mnc'=>$mnc])->exists()) {
                    DB::table('network_mncs')->insert([
                        'network_id'=>$network->id,
                        'mcc'=>$mcc,
                        'mnc'=>$mnc,
                        'mcc_mnc'=>$mcc.$mnc,
                        'created_at'=>now(),'updated_at'=>now(),
                    ]);
                    $createdMncs++;
                }
            }
        });

        return ['ok'=>true,'msg'=>'Import complete','createdCountries'=>$createdCountries,'createdNetworks'=>$createdNetworks,'createdMncs'=>$createdMncs];
    }
}
