<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\HyperController;

Route::middleware(['api'])->group(function () {
    Route::get('hyper', [HyperController::class, 'getHyper']);
    Route::post('hyper', [HyperController::class, 'setHyper']);
    Route::put('hyper/own', [HyperController::class, 'ownHyper']);
});