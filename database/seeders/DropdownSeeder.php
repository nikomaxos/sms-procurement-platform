<?php
namespace Database\Seeders;
use Illuminate\Database\Seeder;
use App\Models\RouteType;
use App\Models\KnownHop;
use App\Models\ChargeModel;
class DropdownSeeder extends Seeder
{
    public function run(): void
    {
        foreach (['Direct','HQ','SS7','SIM','Local Bypass'] as $v) { RouteType::firstOrCreate(['name'=>$v]); }
        foreach (['0-Hop','1-Hop','2-Hops','N-Hops'] as $v) { KnownHop::firstOrCreate(['name'=>$v]); }
        foreach (['Per Submit','Per Delivered'] as $v) { ChargeModel::firstOrCreate(['name'=>$v]); }
    }
}
