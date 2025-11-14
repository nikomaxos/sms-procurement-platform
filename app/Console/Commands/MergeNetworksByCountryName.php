<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class MergeNetworksByCountryName extends Command {
    protected $signature = 'networks:merge-country-name';
    protected $description = 'Merge duplicate networks per (country_id, lower(name)) and re-home MNCs.';

    public function handle(): int {
        $this->info("Scanning duplicates…");
        $dups = DB::table('networks')
            ->select('country_id', DB::raw('lower(name) as lname'), DB::raw('array_agg(id order by id) as ids'))
            ->groupBy('country_id', DB::raw('lower(name)'))
            ->havingRaw('count(*) > 1')
            ->get();

        foreach ($dups as $d) {
            $ids = $d->ids;
            if (!is_array($ids)) $ids = json_decode(str_replace(['{','}'],['[',']'],$ids), true) ?: [];
            if (count($ids) < 2) continue;
            $keep = array_shift($ids);
            $this->info("Merging into #$keep from: ".implode(',', $ids));
            // Re-home MNCs
            DB::table('network_mncs')->whereIn('network_id', $ids)->update(['network_id'=>$keep]);
            // Delete empties
            DB::table('networks')->whereIn('id', $ids)->delete();
        }

        // Enforce unique index (safe if already exists)
        DB::statement("CREATE UNIQUE INDEX IF NOT EXISTS uniq_networks_country_lowername ON networks (country_id, lower(name))");
        $this->info("Done.");
        return 0;
    }
}
