<?php
namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;
use App\Console\Commands\CarriersImport;

class Kernel extends ConsoleKernel
{
    protected $commands = [
        CarriersImport::class,
    ];

    protected function schedule(Schedule $schedule): void
    {
        // $schedule->command('carriers:import --source=itu')->weekly();
    }

    protected function commands(): void
    {
        $this->load(__DIR__.'/Commands');
        if (file_exists(base_path('routes/console.php'))) {
            require base_path('routes/console.php');
        }
    }
}
