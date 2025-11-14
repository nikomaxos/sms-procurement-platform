<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use App\Models\Country;
use App\Models\CountryMcc;
use App\Models\Network;
use App\Models\NetworkMnc;

class ImportCarriers extends Command {
    protected $signature = 'carriers:import {--source=itu} {--fresh : Clear MNC & MCC links before import}';
    protected $description = 'Import carriers from external sources (default: ITU JSON via onomondo repo)';

    public function handle() {
        $source = strtolower((string)($this->option('source') ?? 'itu'));

        if ($this->option('fresh')) {
            DB::statement('TRUNCATE network_mncs RESTART IDENTITY CASCADE');
            DB::statement('TRUNCATE country_mccs RESTART IDENTITY CASCADE');
            $this->info('Cleared network_mncs & country_mccs (networks kept).');
        }

        if ($source !== 'itu') {
            $this->error("Unknown source: {$source}");
            return self::FAILURE;
        }

        $url = 'https://raw.githubusercontent.com/onomondo/mcc-mnc-itu/master/data.json';
        try {
            $resp = Http::timeout(45)->withHeaders([
                'User-Agent' => 'sms-procurement-platform/1.0'
            ])->get($url);
        } catch (\Throwable $e) {
            $this->error('Cannot fetch ITU JSON: '.$e->getMessage());
            return self::FAILURE;
        }
        if (!$resp->ok()) {
            $this->error('Cannot fetch ITU JSON (HTTP '.$resp->status().')');
            return self::FAILURE;
        }

        $rows = $resp->json();
        if (!is_array($rows)) {
            $this->error('Unexpected JSON payload');
            return self::FAILURE;
        }

        $created = $updated = $linked = 0;

        foreach ($rows as $row) {
            $countryName = $row['country'] ?? $row['country_name'] ?? $row['Country'] ?? null;
            $iso2        = $row['alpha_2'] ?? $row['iso2'] ?? $row['ISO'] ?? 'n/a';
            $name        = $row['brand'] ?? $row['operator'] ?? $row['network'] ?? $row['Brand'] ?? null;
            $mcc         = (string)($row['mcc'] ?? $row['MCC'] ?? '');
            $mnc         = (string)($row['mnc'] ?? $row['MNC'] ?? '');

            if (!$countryName || !$name || $mcc === '' || $mnc === '') {
                continue;
            }

            $iso2 = strtolower(substr((string)$iso2, 0, 2) ?: 'n/a');

            $country = Country::firstOrCreate(
                ['name' => $countryName],
                ['iso2' => $iso2]
            );
            CountryMcc::firstOrCreate(['country_id' => $country->id, 'mcc' => $mcc]);

            $net = Network::where('country_id', $country->id)
                ->whereRaw('lower(name) = ?', [mb_strtolower($name, 'UTF-8')])
                ->first();

            if (!$net) {
                $net = new Network();
                $net->country_id = $country->id;
                $net->name = $name;
                if (array_key_exists('mcc', $net->getAttributes())) {
                    $net->mcc = $mcc;
                }
                $created++;
            } else {
                $updated++;
            }
            $net->updated_by_source = 'ITU import';
            $net->save();

            $nm = NetworkMnc::firstOrNew(['mcc' => $mcc, 'mnc' => $mnc]);
            $nm->network_id = $net->id;
            if (!$nm->exists) $nm->created_by_source = 'ITU import';
            $nm->updated_by_source = 'ITU import';
            $nm->save();
            $linked++;
        }

        $this->info("Import done. Networks: +$created created, ~$updated updated; MNC links: $linked");
        return self::SUCCESS;
    }
}
