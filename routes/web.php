<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ProfileController;

Route::get('/', function () { return view('welcome'); });

Route::middleware(['auth'])->group(function () {
    // Dashboard
    Route::view('/dashboard', 'dashboard')->name('dashboard');

    // Profile (Breeze)
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

    // ===== Settings (admin only) =====
    Route::middleware('can:admin')->prefix('settings')->name('settings.')->group(function () {
        Route::get('/', [\App\Http\Controllers\Settings\SettingsController::class, 'index'])->name('index');

        // Users
        Route::resource('users', \App\Http\Controllers\Settings\UserController::class)->except(['show']);

        // Drop-down menus (single index + per-type CRUD)
        Route::get('dropdowns', [\App\Http\Controllers\Settings\RouteTypeController::class, 'index'])->name('dropdowns.index');
        Route::resource('route-types', \App\Http\Controllers\Settings\RouteTypeController::class)->only(['store','update','destroy']);
        Route::resource('known-hops', \App\Http\Controllers\Settings\KnownHopController::class)->only(['store','update','destroy']);
        Route::resource('charge-models', \App\Http\Controllers\Settings\ChargeModelController::class)->only(['store','update','destroy']);

        // Auth logs
        Route::get('logs', [\App\Http\Controllers\Settings\AuthLogController::class, 'index'])->name('logs.index');
    });
});

require __DIR__.'/auth.php';
