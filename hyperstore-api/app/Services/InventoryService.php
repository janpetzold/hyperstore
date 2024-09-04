<?php

namespace App\Services;

use Illuminate\Support\Facades\Redis;

class InventoryService
{
    private $redis;
    private $region;

    public function __construct()
    {
        $this->redis = Redis::connection('inventory');
        $this->region = env('APP_REGION', 'eu');
    }

    public function getInventory($region = null)
    {
        $region = $region ?? $this->region;
        return $this->redis->get("hyper-{$region}") ?? 0;
    }

    public function setInventory($amount, $region = null)
    {
        $region = $region ?? $this->region;
        $this->redis->set("hyper-{$region}", $amount);
    }

    public function incrementInventory($amount = 1, $region = null)
    {
        $region = $region ?? $this->region;
        return $this->redis->incrby("hyper-{$region}", $amount);
    }

    public function decrementInventory($amount = 1, $region = null)
    {
        $region = $region ?? $this->region;
        $newAmount = $this->redis->decrby("hyper-{$region}", $amount);
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