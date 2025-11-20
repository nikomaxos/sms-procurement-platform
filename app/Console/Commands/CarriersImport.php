<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\CarrierImportService;

class CarriersImport extends Command
{
    protected $signature = 'carriers:import {--source=itu} {--fresh}';
    protected $description = 'CarriersImport (service-backed) — uses remote JSON with local fallback, prints JSON summary';

    public function handle(): int {
        $svc = new CarrierImportService();
        $res = $svc->import((string)$this->option('source'), (bool)$this->option('fresh'));
        $this->line(json_encode($res, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
        return $res['ok'] ? Command::SUCCESS : Command::FAILURE;
    }
}
