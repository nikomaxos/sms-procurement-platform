<?php
namespace Database\Seeders;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use App\Models\User;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $email = env('ADMIN_EMAIL', 'admin@example.com');
        $password = env('ADMIN_PASSWORD', 'secret');
        $user = User::firstOrCreate([
            'email' => $email,
        ], [
            'name' => 'Administrator',
            'password' => Hash::make($password),
        ]);
        if (! $user->is_admin) {
            $user->is_admin = true;
            $user->save();
        }
    }
}
