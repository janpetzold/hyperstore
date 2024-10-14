<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\HyperController;

// We need our custom "client" middleware here to protect API access
Route::middleware('client')->group(function () {
    Route::get('hyper', [HyperController::class, 'getHyper']);
    Route::post('hyper', [HyperController::class, 'setHyper']);
    Route::put('hyper/own', [HyperController::class, 'ownHyper']);
});