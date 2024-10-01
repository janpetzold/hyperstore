<?php

namespace App\Http\Middleware;

use Closure;
use Debugbar;

/**
 * This adds Debugbar output to JSON responses if activated
 */
class AppendDebugbar
{
    public function handle($request, Closure $next)
    {
        $response = $next($request);

        if ($response->headers->get('Content-Type') === 'application/json') {
            $debugbar = Debugbar::getData();

            $originalData = json_decode($response->getContent(), true);
            $originalData['_debugbar'] = $debugbar;

            $response->setContent(json_encode($originalData));
        }

        return $response;
    }
}
