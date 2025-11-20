<?php
namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use App\Models\Country;
use App\Models\Network;

/**
 * Imports MCC/MNCs from remote JSON with local fallback and
 * writes provenance (created_by_source / updated_by_source).
 */
class CarrierImportService {

    /**
     * @return array{ok:bool,msg:string,createdCountries:int,createdNetworks:int,createdMncs:int}
     */
    public function import(string $source = 'itu', bool $fresh = false): array {
        $createdCountries = 0; $createdNetworks = 0; $createdMncs = 0;

        if ($fresh) {
            DB::table('network_mncs')->truncate();
            DB::table('country_mccs')->truncate();
        }

        // Determine provenance label
        $provenanceRemote = 'import:itu';
        $provenanceLocal  = 'import:local';

        // Data sources
        $urls = [
            // Canonical public table (schema: mcc, mnc, country, iso, brand/operator)
            'https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.json',
        ];

        // Try remote
        $rows = [];
        foreach ($urls as $url) {
            try {
                $res = Http::timeout(30)->get($url);
                if ($res->successful() && is_array($res->json())) {
                    $rows = array_merge($rows, $res->json());
                }
            } catch (\Throwable $e) {
                // ignore and try next
            }
        }

        $provenance = $rows ? $provenanceRemote : $provenanceLocal;

        // Fallback: local bundled JSON
        if (!$rows) {
            $path = base_path('resources/data/mcc-mnc-table.json');
            if (is_file($path)) {
                $data = json_decode((string)file_get_contents($path), true);
                if (is_array($data)) $rows = $data;
            }
        }

        if (!$rows) {
            return ['ok'=>false,'msg'=>'No data fetched from any source','createdCountries'=>0,'createdNetworks'=>0,'createdMncs'=>0];
        }

        // Dedupe within the batch to avoid redundant upserts
        $seenMccMnc = [];

        DB::transaction(function () use ($rows, &$createdCountries, &$createdNetworks, &$createdMncs, $provenance) {

            $hasLowerName = Schema::hasColumn('networks', 'lower_name');

            foreach ($rows as $r) {
                $mcc = trim((string)($r['mcc'] ?? $r['MCC'] ?? ''));
                $mnc = trim((string)($r['mnc'] ?? $r['MNC'] ?? ''));
                $cname = trim((string)($r['country'] ?? $r['country_name'] ?? $r['countryName'] ?? ''));
                $iso2  = strtolower(trim((string)($r['iso'] ?? $r['iso2'] ?? $r['country_code'] ?? '')));
                $netName = trim((string)($r['brand'] ?? $r['operator'] ?? $r['network'] ?? ''));

                if ($mcc === '' || $mnc === '' || $cname === '' || $netName === '') {
                    continue;
                }

                // Normalize & pad
                $mccPad = str_pad(preg_replace('/\D+/', '', $mcc), 3, '0', STR_PAD_LEFT);
                $mncPad = str_pad(preg_replace('/\D+/', '', $mnc), 3, '0', STR_PAD_LEFT);
                $mccMnc = $mccPad . $mncPad;

                // Country match → prefer ISO2 when available
                $country = null;
                if ($iso2 !== '') {
                    $country = Country::whereRaw('lower(iso2) = ?', [$iso2])->first();
                }
                if (!$country) {
                    $country = Country::whereRaw('lower(name) = ?', [mb_strtolower($cname)])->first();
                }
                if (!$country) {
                    $country = Country::create(['name' => $cname, 'iso2' => $iso2 ?: null]);
                    $createdCountries++;
                }

                // Network match by (country_id, lower(name))
                $lower = mb_strtolower($netName);
                $netQ = Network::where('country_id', $country->id)->whereRaw('lower(name) = ?', [$lower]);
                $network = $netQ->first();

                if (!$network) {
                    $attrs = ['country_id' => $country->id, 'name' => $netName];
                    if ($hasLowerName) $attrs['lower_name'] = $lower;
                    $network = Network::create($attrs);
                    $createdNetworks++;
                } else {
                    // Keep lower_name in sync if the column exists
                    if ($hasLowerName && $network->lower_name !== $lower) {
                        $network->lower_name = $lower;
                        $network->save();
                    }
                }

                // country_mccs upsert (unique per mcc)
                $existsCountryMcc = DB::table('country_mccs')->where('mcc', $mccPad)->exists();
                if ($existsCountryMcc) {
                    DB::table('country_mccs')
                      ->where('mcc', $mccPad)
                      ->update([
                          'country_id'        => $country->id,
                          'updated_by_source' => $provenance,
                          'updated_at'        => now(),
                      ]);
                } else {
                    DB::table('country_mccs')->insert([
                        'country_id'        => $country->id,
                        'mcc'               => $mccPad,
                        'created_by_source' => $provenance,
                        'updated_by_source' => $provenance,
                        'created_at'        => now(),
                        'updated_at'        => now(),
                    ]);
                }

                // network_mncs upsert (unique per (mcc,mnc))
                $key = $mccPad.'-'.$mncPad;
                if (isset($seenMccMnc[$key])) {
                    continue; // skip duplicates inside the same batch
                }
                $seenMccMnc[$key] = true;

                $existsMnc = DB::table('network_mncs')
                    ->where('mcc', $mccPad)->where('mnc', $mncPad)->exists();

                if ($existsMnc) {
                    DB::table('network_mncs')
                        ->where('mcc', $mccPad)
                        ->where('mnc', $mncPad)
                        ->update([
                            'network_id'        => $network->id,
                            'mcc_mnc'           => $mccMnc,
                            'updated_by_source' => $provenance,
                            'updated_at'        => now(),
                        ]);
                } else {
                    DB::table('network_mncs')->insert([
                        'network_id'        => $network->id,
                        'mcc'               => $mccPad,
                        'mnc'               => $mncPad,
                        'mcc_mnc'           => $mccMnc,
                        'created_by_source' => $provenance,
                        'updated_by_source' => $provenance,
                        'created_at'        => now(),
                        'updated_at'        => now(),
                    ]);
                    $createdMncs++;
                }
            }
        });

        return [
            'ok' => true,
            'msg' => 'Import completed',
            'createdCountries' => $createdCountries,
            'createdNetworks'  => $createdNetworks,
            'createdMncs'      => $createdMncs,
        ];
    }
}
