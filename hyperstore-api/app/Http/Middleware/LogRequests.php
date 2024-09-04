<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Support\Facades\Redis;
use Carbon\Carbon;

class LogRequests
{
    public function handle($request, Closure $next)
    {
        $redis = app('redis')->connection('requestlog');

        $currentMinute = Carbon::now()->format('Y-m-d\TH:i:00\Z');
        $key = "{$currentMinute}";

        // Increment the count for the current minute
        $redis->incr($key);

        // Set expiry to 1 month (approximately 30 days or 2,592,000 seconds)
        $redis->expire($key, 2592000);

        // Log the current count for this minute
        $count = $redis->get($key);
        \Log::info("Request count for {$currentMinute}: {$count}");

        // Optionally, you can retrieve and log the last hour's worth of data
        for ($i = 1; $i <= 60; $i++) {
            $pastMinute = Carbon::now()->subMinutes($i)->format('Y-m-d H:i');
            $pastKey = "requests:{$pastMinute}";
            if ($redis->exists($pastKey)) {
                $pastCount = $redis->get($pastKey);
                \Log::info("Historical data - {$pastMinute}: {$pastCount}");
            }
        }

        return $next($request);
    }
}