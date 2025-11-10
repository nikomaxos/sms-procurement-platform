<?php
namespace Database\Seeders;
use Illuminate\Database\Seeder;
class DatabaseSeeder extends Seeder
{
    public function run(): void {
        ->call(\Database\Seeders\DropdownSeeder::class);
$this->call([
            AdminUserSeeder::class,
        ]);
    }
}
