<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DropdownSeeder extends Seeder
{
    public function run(): void
    {
        DB::statement('TRUNCATE TABLE dropdown_items CASCADE;');
        DB::statement('TRUNCATE TABLE dropdown_menus CASCADE;');

        \Illuminate\Support\Facades\DB::table('dropdown_menus')->insert([
  0 => 
  [
    'id' => 1,
    'title' => 'Product Type',
    'created_at' => '2026-03-10 07:39:24',
    'updated_at' => '2026-03-10 07:51:38',
    'module' => 'supplier_offers',
  ],
  1 => 
  [
    'id' => 2,
    'title' => 'Known Hops',
    'created_at' => '2026-03-10 07:52:01',
    'updated_at' => '2026-03-10 07:52:01',
    'module' => 'supplier_offers',
  ],
  2 => 
  [
    'id' => 3,
    'title' => 'Sender ID Supported',
    'created_at' => '2026-03-10 08:04:45',
    'updated_at' => '2026-03-10 08:04:45',
    'module' => 'supplier_offers',
  ],
]);

        \Illuminate\Support\Facades\DB::table('dropdown_items')->insert([
  0 => 
  [
    'id' => 2,
    'dropdown_menu_id' => 2,
    'label' => '0-Hop',
    'created_at' => '2026-03-10 07:52:16',
    'updated_at' => '2026-03-10 07:52:16',
    'position' => 0,
  ],
  1 => 
  [
    'id' => 3,
    'dropdown_menu_id' => 2,
    'label' => '1-Hop',
    'created_at' => '2026-03-10 07:53:08',
    'updated_at' => '2026-03-10 07:53:08',
    'position' => 0,
  ],
  2 => 
  [
    'id' => 4,
    'dropdown_menu_id' => 2,
    'label' => '2-Hops',
    'created_at' => '2026-03-10 07:53:23',
    'updated_at' => '2026-03-10 07:53:23',
    'position' => 0,
  ],
  3 => 
  [
    'id' => 5,
    'dropdown_menu_id' => 2,
    'label' => 'N-Hops',
    'created_at' => '2026-03-10 07:53:30',
    'updated_at' => '2026-03-10 07:53:30',
    'position' => 0,
  ],
  4 => 
  [
    'id' => 1,
    'dropdown_menu_id' => 1,
    'label' => 'Direct',
    'created_at' => '2026-03-10 07:39:35',
    'updated_at' => '2026-03-10 07:55:36',
    'position' => 0,
  ],
  5 => 
  [
    'id' => 6,
    'dropdown_menu_id' => 1,
    'label' => 'HQ',
    'created_at' => '2026-03-10 07:55:50',
    'updated_at' => '2026-03-10 07:55:50',
    'position' => 0,
  ],
  6 => 
  [
    'id' => 7,
    'dropdown_menu_id' => 1,
    'label' => 'SS7',
    'created_at' => '2026-03-10 07:56:05',
    'updated_at' => '2026-03-10 07:56:05',
    'position' => 0,
  ],
  7 => 
  [
    'id' => 8,
    'dropdown_menu_id' => 1,
    'label' => 'SS7 Partners',
    'created_at' => '2026-03-10 07:56:12',
    'updated_at' => '2026-03-10 07:56:12',
    'position' => 0,
  ],
  8 => 
  [
    'id' => 9,
    'dropdown_menu_id' => 1,
    'label' => 'SIM',
    'created_at' => '2026-03-10 07:56:27',
    'updated_at' => '2026-03-10 07:56:27',
    'position' => 0,
  ],
  9 => 
  [
    'id' => 10,
    'dropdown_menu_id' => 1,
    'label' => 'Local Bypass',
    'created_at' => '2026-03-10 07:56:55',
    'updated_at' => '2026-03-10 07:56:55',
    'position' => 0,
  ],
  10 => 
  [
    'id' => 11,
    'dropdown_menu_id' => 1,
    'label' => 'Viber OTP',
    'created_at' => '2026-03-10 07:57:10',
    'updated_at' => '2026-03-10 07:57:10',
    'position' => 0,
  ],
  11 => 
  [
    'id' => 12,
    'dropdown_menu_id' => 1,
    'label' => 'Whatsapp OTP',
    'created_at' => '2026-03-10 07:57:31',
    'updated_at' => '2026-03-10 07:57:31',
    'position' => 0,
  ],
  12 => 
  [
    'id' => 13,
    'dropdown_menu_id' => 1,
    'label' => 'Telegram OTP',
    'created_at' => '2026-03-10 07:57:45',
    'updated_at' => '2026-03-10 07:57:45',
    'position' => 0,
  ],
  13 => 
  [
    'id' => 14,
    'dropdown_menu_id' => 1,
    'label' => 'Voice OTP',
    'created_at' => '2026-03-10 07:57:54',
    'updated_at' => '2026-03-10 07:57:54',
    'position' => 0,
  ],
  14 => 
  [
    'id' => 15,
    'dropdown_menu_id' => 3,
    'label' => 'Dynamic Alphanumeric',
    'created_at' => '2026-03-10 08:05:02',
    'updated_at' => '2026-03-10 08:05:02',
    'position' => 0,
  ],
  15 => 
  [
    'id' => 16,
    'dropdown_menu_id' => 3,
    'label' => 'Dynamic Numeric',
    'created_at' => '2026-03-10 08:05:14',
    'updated_at' => '2026-03-10 08:05:14',
    'position' => 0,
  ],
  16 => 
  [
    'id' => 17,
    'dropdown_menu_id' => 3,
    'label' => 'Random Numeric',
    'created_at' => '2026-03-10 08:05:48',
    'updated_at' => '2026-03-10 08:05:48',
    'position' => 0,
  ],
  17 => 
  [
    'id' => 18,
    'dropdown_menu_id' => 3,
    'label' => 'Shared Short Code',
    'created_at' => '2026-03-10 08:05:59',
    'updated_at' => '2026-03-10 08:05:59',
    'position' => 0,
  ],
  18 => 
  [
    'id' => 19,
    'dropdown_menu_id' => 3,
    'label' => 'Dedicated Short Code',
    'created_at' => '2026-03-10 08:06:20',
    'updated_at' => '2026-03-10 08:06:20',
    'position' => 0,
  ],
  19 => 
  [
    'id' => 20,
    'dropdown_menu_id' => 3,
    'label' => 'Fixed Alphanumeric',
    'created_at' => '2026-03-10 08:09:09',
    'updated_at' => '2026-03-10 08:09:09',
    'position' => 0,
  ],
]);

    }
}