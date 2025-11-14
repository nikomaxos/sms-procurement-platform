<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\CarrierImportService;

class CarriersImport extends Command
{
    protected $signature = 'carriers:import {--source=itu} {--fresh}';
    protected $description = 'Import carriers/MNCs from public dataset (best-effort).';

    public function handle()
    {
        $source = strtolower((string)$this->option('source'));
        $fresh  = (bool)$this->option('fresh');
        [$ok,$msg] = (new CarrierImportService())->import($source, $fresh);
        $this->line($msg);
        return $ok ? self::SUCCESS : self::FAILURE;
    }
}
