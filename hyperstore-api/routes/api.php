<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\HyperController;

// We only need "web" middleware here since we rely on session variables
Route::middleware(['web'])->group(function () {
    Route::get('hyper', [HyperController::class, 'getHyper']);
    Route::post('hyper', [HyperController::class, 'setHyper']);
    Route::put('hyper/own', [HyperController::class, 'ownHyper']);
});