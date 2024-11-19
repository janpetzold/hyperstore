<?php

namespace App\Services;

use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Log;

class InventoryService
{
    private $region;

    public function __construct()
    {
        $this->region = config('app.region', 'eu');
        $this->validateRedisConnection();
    }

    private function validateRedisConnection()
    {
        try {
            $ping = Redis::connection()->ping();
            if ($ping === "pong" || $ping == 1) {
                $redisHost = config('database.redis.inventory.host');
                Log::debug("Redis connection to host {$redisHost} successful");
            } else {
                Log::error("Could not verify Redis connection");
            }
        } catch (\Exception $e) {
            Log::error("Redis connection failed: " . $e->getMessage());
        }
    }

    public function getInventory($region = null)
    {
        $region = $region ?? $this->region;
        return Redis::connection()->get("hyper-{$region}") ?? 0;
    }

    public function setInventory($amount, $region = null)
    {
        $region = $region ?? $this->region;
        Redis::connection()->set("hyper-{$region}", $amount);
    }

    public function incrementInventory($amount = 1, $region = null)
    {
        $region = $region ?? $this->region;
        return Redis::connection()->incrby("hyper-{$region}", $amount);
    }

    public function decrementInventory($amount = 1, $region = null)
    {
        $region = $region ?? $this->region;
        $newAmount = Redis::connection()->decrby("hyper-{$region}", $amount);
        return max($newAmount, 0);  // Ensure inventory doesn't go below 0
    }

    public function getAllInventory()
    {
        return [
            'eu' => $this->getInventory('eu'),
            'na' => $this->getInventory('na'),
            'sa' => $this->getInventory('sa'),
        ];
    }
}