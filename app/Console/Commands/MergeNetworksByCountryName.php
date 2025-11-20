<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\NetworkMergeService;

class MergeNetworksByCountryName extends Command
{
    protected $signature = 'networks:dedupe {--country=} {--dry-run}';
    protected $description = 'Merge duplicate networks per (country_id, lower(name)). Move MNCs & delete losers.';

    public function handle(NetworkMergeService $svc)
    {
        $country = $this->option('country') ? (int)$this->option('country') : null;
        $dry     = (bool)$this->option('dry-run');

        $this->info(($dry ? '[DRY-RUN] ' : '') . 'Scanning for duplicate network groups…');
        $report = $svc->mergeAll($country, $dry);

        $ts = now()->format('Ymd_His');
        $log = storage_path('logs').'/networks_merge_'.($country ?? 'all')."_{$ts}.log";

        $out  = [];
        $out[] = json_encode($report, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES);
        foreach ($report['details'] as $d) {
            foreach (($d['notes'] ?? []) as $n) $out[] = $n;
        }
        file_put_contents($log, implode(PHP_EOL, $out).PHP_EOL);

        $this->line(implode(PHP_EOL, $out));
        $this->info("Log: $log");
        return self::SUCCESS;
    }
}
