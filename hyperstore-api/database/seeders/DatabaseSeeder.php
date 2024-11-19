<?php

namespace Database\Seeders;

// use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Database\QueryException;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void {
        // Add our OAuth2 client
        try {
            DB::table('oauth_clients')->insert([
                'id' => '9d3eeae0-bb6d-4886-a282-99c6ba31728b',
                'user_id' => null,
                'name' => 'HyperStore Scope Test',
                'secret' => 'nOIxkbi40JJXicrAPJXZWaMcJuGKH6rwpkrWylVe',
                'provider' => null,
                'redirect' => 'http://localhost',
                'personal_access_client' => true,
                'password_client' => false,
                'revoked' => false,
                'created_at' => '2024-10-14 19:52:21',
                'updated_at' => '2024-10-14 19:52:21'
            ]);

            $this->command->info('OAuth client seeded successfully.');
        } catch (QueryException $e) {
            // Check if this is a duplicate entry error
            if ($e->errorInfo[1] === 1062) {
                $this->command->info('OAuth client already exists - skipping.');
            } else {
                // If it's a different error, we still want to know about it
                throw $e;
            }
        }
    }
}
