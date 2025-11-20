<?php
namespace App\Services;

use Illuminate\Support\Facades\DB;

class NetworkMergeService
{
    /**
     * Find duplicate groups by (country_id, lower(name)).
     * @param int|null $countryId optional filter
     * @return array<int,array{country_id:int, lower_name:string, ids:array<int>, names:array<string>, count:int}>
     */
    public function findDuplicateGroups(?int $countryId = null): array
    {
        $rows = DB::table('networks')
            ->selectRaw('country_id, lower(name) AS lower_name, array_agg(id ORDER BY id) AS ids, array_agg(name ORDER BY id) AS names, count(*)::int AS count')
            ->when($countryId, fn($q)=>$q->where('country_id',$countryId))
            ->groupBy('country_id', DB::raw('lower(name)'))
            ->havingRaw('count(*) > 1')
            ->orderBy('country_id')
            ->orderBy('lower_name')
            ->get();

        return $rows->map(function($r){
            return [
                'country_id' => (int)$r->country_id,
                'lower_name' => (string)$r->lower_name,
                'ids'        => array_map('intval', $r->ids ?? []),
                'names'      => array_map('strval', $r->names ?? []),
                'count'      => (int)$r->count,
            ];
        })->all();
    }

    /**
     * Merge one duplicate group into a single survivor.
     * Moves all network_mncs from losers to survivor (respecting unique (mcc,mnc)), deletes losers.
     *
     * @param int      $countryId
     * @param string   $lowerName
     * @param int|null $preferredId survivor if present; otherwise smallest id wins
     * @param bool     $dryRun
     * @return array{survivor:int, losers:array<int>, moved:int, deleted:int, notes:array<string>}
     */
    public function mergeGroup(int $countryId, string $lowerName, ?int $preferredId = null, bool $dryRun = false): array
    {
        $group = DB::table('networks')
            ->select('id','name')
            ->where('country_id',$countryId)
            ->whereRaw('lower(name) = ?', [mb_strtolower($lowerName)])
            ->orderBy('id')
            ->get();

        if ($group->count() < 2) {
            return ['survivor'=>0,'losers'=>[],'moved'=>0,'deleted'=>0,'notes'=>["No duplicates for [$countryId,$lowerName]"]];
        }

        $ids   = $group->pluck('id')->all();
        $names = $group->pluck('name','id')->all();

        $survivor = $preferredId && in_array($preferredId,$ids, true) ? $preferredId : min($ids);
        $losers   = array_values(array_diff($ids, [$survivor]));
        $notes    = ["Group {$countryId}/{$lowerName}: survivor=$survivor ({$names[$survivor]}) losers=[".implode(',',$losers)."]"];

        $moved = 0; $deleted = 0;

        if ($dryRun) {
            foreach ($losers as $lid) {
                $cnt = DB::table('network_mncs')->where('network_id',$lid)->count();
                $notes[] = "Would reassign $cnt MNC rows from loser $lid -> survivor $survivor";
            }
            return ['survivor'=>$survivor,'losers'=>$losers,'moved'=>$moved,'deleted'=>$deleted,'notes'=>$notes];
        }

        return DB::transaction(function() use ($losers, $survivor, $countryId, $lowerName, $names, $notes, &$moved, &$deleted) {
            foreach ($losers as $lid) {
                // Reassign all MNC rows to survivor; unique(mcc,mnc) prevents dup rows globally.
                $cnt = DB::table('network_mncs')->where('network_id',$lid)->update(['network_id'=>$survivor]);
                $moved += $cnt;

                // Delete loser network
                DB::table('networks')->where('id',$lid)->delete();
                $deleted++;
            }
            return ['survivor'=>$survivor,'losers'=>$losers,'moved'=>$moved,'deleted'=>$deleted,'notes'=>$notes];
        });
    }

    /**
     * Merge all duplicate groups (optionally limited to a country).
     * @return array{total_groups:int, merged:int, moved:int, deleted:int, details:array}
     */
    public function mergeAll(?int $countryId = null, bool $dryRun = false): array
    {
        $groups = $this->findDuplicateGroups($countryId);
        $merged = 0; $moved = 0; $deleted = 0; $details = [];

        foreach ($groups as $g) {
            $res = $this->mergeGroup($g['country_id'], $g['lower_name'], null, $dryRun);
            if (count($res['losers']) > 0) { $merged++; }
            $moved   += $res['moved'];
            $deleted += $res['deleted'];
            $details[] = $res;
        }

        return ['total_groups'=>count($groups), 'merged'=>$merged, 'moved'=>$moved, 'deleted'=>$deleted, 'details'=>$details];
    }
}
