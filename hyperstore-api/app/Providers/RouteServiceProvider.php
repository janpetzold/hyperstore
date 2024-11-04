<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Foundation\Support\Providers\RouteServiceProvider as ServiceProvider;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;

class RouteServiceProvider extends ServiceProvider
{
    /**
     * The path to your application's "home" route.
     *
     * Typically, users are redirected here after authentication.
     *
     * @var string
     */
    public const HOME = '/home';

    // Custom rate limit, needed both for our API and also OAuth endpoints
    public const RATE_LIMIT_PER_MINUTE = 6000;

    /**
     * Define your route model bindings, pattern filters, and other route configuration.
     */
    public function boot(): void
    {
        RateLimiter::for('api', function (Request $request) {
            // This limit is higher than the default of 60 requests/minute
            return Limit::perMinute(self::RATE_LIMIT_PER_MINUTE)->by($request->user()?->id ?: $request->ip());
        });

        $this->routes(function () {
            Route::middleware('api')
                ->prefix('api')
                ->group(base_path('routes/api.php'));

            //Route::middleware('web')
            //    ->group(base_path('routes/web.php'));

            // Register Passport routes for custom rate limiting
            Route::group(['prefix' => 'oauth'], function () {
                
                Route::post('/token', [
                    'uses' => '\Laravel\Passport\Http\Controllers\AccessTokenController@issueToken',
                    'middleware' => 'throttle:' . self::RATE_LIMIT_PER_MINUTE . ',1',
                ]);

                Route::get('/tokens', [
                    'uses' => '\Laravel\Passport\Http\Controllers\AuthorizedAccessTokenController@forUser',
                    'middleware' => ['auth:api', 'scopes:read'],
                ]);

                Route::delete('/tokens/{token_id}', [
                    'uses' => '\Laravel\Passport\Http\Controllers\AuthorizedAccessTokenController@destroy',
                    'middleware' => ['auth:api', 'scopes:read'],
                ]);

                Route::post('/token/refresh', [
                    'uses' => '\Laravel\Passport\Http\Controllers\TransientTokenController@refresh',
                    'middleware' => ['auth:api', 'scopes:read'],
                ]);
            });
        });
    }
}
