<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Support\Facades\Redis;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;

class LogRequests
{
    public function handle($request, Closure $next)
    {
        try {
            $redis = Redis::connection('requestlog');
            $redis->ping();
        } catch (\Exception $e) {
            Log::error("Redis connection failed: " . $e->getMessage());
            return $next($request);
        }

        // This goes on only if Redis is working
        $currentMinute = Carbon::now()->format('Y-m-d\TH:i:00\Z');
        $key = "{$currentMinute}";

        // Increment the count for the current minute
        $redis->incr($key);

        // Set expiry to 1 month (approximately 30 days or 2,592,000 seconds)
        $redis->expire($key, 2592000);

        // Log the current count for this minute
        $count = $redis->get($key);
        Log::debug("Request count for {$currentMinute}: {$count}");

        return $next($request);
    }
}