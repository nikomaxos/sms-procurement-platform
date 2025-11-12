<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\ImapSettingsController;
use App\Http\Controllers\DropDownController;

Route::get('/', function () {
    return view('welcome');
});

// Authenticated area
Route::middleware(['auth'])->group(function () {
    // Dashboard
    Route::get('/dashboard', function () { return view('dashboard'); })->name('dashboard');

    // Settings hub + subpages
    Route::get('/settings/imap', [ImapSettingsController::class, 'edit'])->name('settings.imap.edit');

    // Profile management (if Breeze profile controller exists)
    if (class_exists(ProfileController::class)) {
        Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
        Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
        Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
    }
});

if (file_exists(__DIR__.'/auth.php')) {
    require __DIR__.'/auth.php';
}

// Change Password (auth)
Route::middleware('auth')->group(function () {
    Route::get('/password/change', [\App\Http\Controllers\Auth\PasswordChangeController::class, 'edit'])
        ->name('password.change');
    Route::put('/password/change', [\App\Http\Controllers\Auth\PasswordChangeController::class, 'update'])
        ->name('password.change.update');
});

// Users Management (admin-only via controller middleware implemented in controller)
Route::middleware(['auth'])->prefix('settings')->name('settings.')->group(function () {
    Route::resource('users', \App\Http\Controllers\Settings\UsersManagementController::class)
        ->except(['show'])
        ->names('users');
});

// Drop Down Menus + Items (auth)
Route::middleware(['auth'])->prefix('settings/dropdowns')->name('settings.dropdowns.')->group(function () {
    // Menus
    Route::get('/', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'index'])->name('index');
    Route::get('/create', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'create'])->name('create');
    Route::post('/', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'store'])->name('store');
    Route::get('/{menu}/edit', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'edit'])->name('edit');
    Route::put('/{menu}', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'update'])->name('update');
    Route::delete('/{menu}', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'destroy'])->name('destroy');

    // Items (within a menu)
    Route::get('/{menu}/items', [\App\Http\Controllers\Settings\DropdownItemController::class, 'index'])->name('items.index');
    Route::post('/{menu}/items', [\App\Http\Controllers\Settings\DropdownItemController::class, 'store'])->name('items.store');
    Route::get('/{menu}/items/{item}/edit', [\App\Http\Controllers\Settings\DropdownItemController::class, 'edit'])->name('items.edit');
    Route::put('/{menu}/items/{item}', [\App\Http\Controllers\Settings\DropdownItemController::class, 'update'])->name('items.update');
    Route::delete('/{menu}/items/{item}', [\App\Http\Controllers\Settings\DropdownItemController::class, 'destroy'])->name('items.destroy');
});

// Drop Down Menus + Items (auth)
Route::middleware(['auth'])->prefix('settings/dropdowns')->name('settings.dropdowns.')->group(function () {
    // Menus
    Route::get('/', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'index'])->name('index');
    Route::get('/create', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'create'])->name('create');
    Route::post('/', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'store'])->name('store');
    Route::get('/{menu}/edit', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'edit'])->name('edit');
    Route::put('/{menu}', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'update'])->name('update');
    Route::delete('/{menu}', [\App\Http\Controllers\Settings\DropdownMenuController::class, 'destroy'])->name('destroy');

    // Items
    Route::get('/{menu}/items', [\App\Http\Controllers\Settings\DropdownItemController::class, 'index'])->name('items.index');
    Route::post('/{menu}/items', [\App\Http\Controllers\Settings\DropdownItemController::class, 'store'])->name('items.store');
    Route::get('/{menu}/items/{item}/edit', [\App\Http\Controllers\Settings\DropdownItemController::class, 'edit'])->name('items.edit');
    Route::put('/{menu}/items/{item}', [\App\Http\Controllers\Settings\DropdownItemController::class, 'update'])->name('items.update');
    Route::delete('/{menu}/items/{item}', [\App\Http\Controllers\Settings\DropdownItemController::class, 'destroy'])->name('items.destroy');
});

Route::post(
  '/settings/dropdowns/{menu}/items/reorder',
  [\App\Http\Controllers\Settings\DropdownItemController::class, 'reorder']
)->middleware('auth')->name('settings.dropdowns.items.reorder');


Route::middleware(["auth"])->group(function () {
    Route::get("/settings/imap", [\App\Http\Controllers\ImapSettingsController::class, "edit"])->name("settings.imap.edit");
    Route::put("/settings/imap", [\App\Http\Controllers\ImapSettingsController::class, "update"])->name("settings.imap.update");
});

Route::middleware(['auth'])->group(function () {
    Route::put('/settings/imap', [\App\Http\Controllers\ImapSettingsController::class, 'update'])->name('settings.imap.update');
});

Route::middleware(['auth'])->group(function () {
});

Route::middleware(['auth'])->group(function () {
});

Route::middleware(['auth'])->group(function () {
    // Save (PUT remains as-is elsewhere)
    // Test & Fetch: allow POST or PUT so they work from the single form with _method=PUT
});

Route::middleware(['auth'])->group(function () {
    Route::match(['POST','PUT'], '/settings/imap/test',  [\App\Http\Controllers\ImapSettingsController::class, 'test'])->name('settings.imap.test');
    Route::match(['POST','PUT'], '/settings/imap/fetch', [\App\Http\Controllers\ImapSettingsController::class, 'fetchFolders'])->name('settings.imap.fetch');
});
