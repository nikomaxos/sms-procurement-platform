<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class BackfillLegacyMncs extends Command {
    protected $signature = 'networks:backfill-mncs';
    protected $description = 'Copy legacy networks.mcc/mnc into network_mncs if the relation is empty';

    public function handle(): int {
        $count = 0;
        DB::transaction(function() use (&$count){
            $rows = DB::table('networks')
              ->leftJoin('network_mncs','network_mncs.network_id','=','networks.id')
              ->select('networks.id','networks.mcc','networks.mnc', DB::raw('COUNT(network_mncs.id) as rel_count'))
              ->groupBy('networks.id','networks.mcc','networks.mnc')
              ->get();
            foreach ($rows as $r) {
                if ((int)$r->rel_count === 0 && $r->mcc && $r->mnc) {
                    $mcc = preg_replace('/\D+/', '', (string)$r->mcc);
                    $mnc = preg_replace('/\D+/', '', (string)$r->mnc);
                    if ($mcc !== '' && $mnc !== '') {
                        $mccmnc = $mcc.$mnc;
                        DB::table('network_mncs')->updateOrInsert(
                            ['mcc_mnc' => $mccmnc],
                            [
                                'network_id' => $r->id,
                                'mcc' => $mcc,
                                'mnc' => $mnc,
                                'created_by_source' => 'Backfill',
                                'updated_by_source' => 'Backfill',
                                'created_at' => now(),
                                'updated_at' => now(),
                            ]
                        );
                        $count++;
                    }
                }
            }
        });
        $this->info("Backfilled MNC rows: $count");
        return Command::SUCCESS;
    }
}
