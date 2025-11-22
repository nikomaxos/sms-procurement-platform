<?php
use App\Http\Controllers\NetworkDedupController;

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\ImapSettingsController;
use App\Http\Controllers\DropDownController;

Route::get('/healthz', fn() => response('ok', 200));

Route::get('/', function () {
    return view('welcome');
});

// Authenticated area
Route::middleware(['auth'])->group(function () {
    // Dashboard
    Route::get('/dashboard', function () { return view('dashboard'); })->name('dashboard');

    // Settings hub + subpages
    Route::get('/settings/imap', [ImapSettingsController::class, 'edit'])->middleware(\App\Http\Middleware\AdminOnly::class) ->name('settings.imap.edit');

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


// === Countries & Networks (top-level) ===
Route::middleware(["auth"])->group(function () {
    Route::get("/countries", [\App\Http\Controllers\CountriesController::class, "index"])->name("countries.index");
    Route::get("/countries/create", [\App\Http\Controllers\CountriesController::class, "create"])->name("countries.create");
    Route::post("/countries", [\App\Http\Controllers\CountriesController::class, "store"])->name("countries.store");
    Route::get("/countries/{country}/edit", [\App\Http\Controllers\CountriesController::class, "edit"])->name("countries.edit");
    Route::delete("/countries/{country}", [\App\Http\Controllers\CountriesController::class, "destroy"])->name("countries.destroy");
    Route::get("/countries/lookup", [\App\Http\Controllers\CountriesController::class, "lookup"])->name("countries.lookup");

    Route::get("/networks", [\App\Http\Controllers\NetworksController::class, "index"])->name("networks.index");
    Route::get("/networks/create", [\App\Http\Controllers\NetworksController::class, "create"])->name("networks.create");
    Route::post("/networks", [\App\Http\Controllers\NetworksController::class, "store"])->name("networks.store");
    Route::get("/networks/{network}/edit", [\App\Http\Controllers\NetworksController::class, "edit"])->name("networks.edit");
    Route::put("/networks/{network}", [\App\Http\Controllers\NetworksController::class, "update"])->name("networks.update");
    Route::delete("/networks/{network}", [\App\Http\Controllers\NetworksController::class, "destroy"])->name("networks.destroy");
});


// === Carriers Import (UI trigger) ===

use App\Http\Controllers\CarriersImportController;

// ---- Carriers import routes (round18 fixed) ----
Route::middleware(['auth'])->group(function () {
    Route::view('/carriers/import', 'carriers.import')->name('carriers.import.form');
    Route::post(
        '/carriers/import',
        [\App\Http\Controllers\CarriersImportController::class, 'run']
    )->name('carriers.import');
});

// === MCC/MNC management (Step2) ===
use App\Http\Controllers\CountryMccController;
use App\Http\Controllers\NetworkMncController;

Route::middleware(['auth'])->group(function () {
    // Country MCCs (unique MCC globally; reassignment allowed)
    Route::post('/countries/{country}/mccs', [CountryMccController::class, 'store'])->name('countries.mccs.store');
    Route::delete('/countries/{country}/mccs/{mcc}', [CountryMccController::class, 'destroy'])->name('countries.mccs.destroy');

    // Network MCC/MNC pairs (unique pair globally; reassignment allowed)
    Route::post('/networks/{network}/mncs', [NetworkMncController::class, 'store'])->name('networks.mncs.store');
    Route::delete('/networks/{network}/mncs/{mcc}/{mnc}', [NetworkMncController::class, 'destroy'])->name('networks.mncs.destroy');
});

// ---- override countries.update to use CountryUpdateProxy ----
Route::middleware(['auth'])->group(function () {
    Route::put('/countries/{country}', [\App\Http\Controllers\CountryUpdateProxy::class, '__invoke'])
        ->name('countries.update');
});

// === API (auth) for country search + mccs ===
Route::middleware(['auth'])->prefix('api')->group(function () {
    Route::get('/countries/search', \App\Http\Controllers\Api\CountrySearchController::class);
    Route::get('/countries/{country}/mccs', \App\Http\Controllers\Api\CountryMccsController::class);
});

// === Networks Duplicates (admin) ===
Route::middleware(["auth","admin"])->prefix("networks")->name("networks.")->group(function(){
    Route::get("/duplicates", [\App\Http\Controllers\NetworkDedupController::class, "index"])->name("duplicates.index");
    Route::post("/duplicates/merge", [\App\Http\Controllers\NetworkDedupController::class, "merge"])->name("duplicates.merge");
});

// === Country MCC reassign (admin) ===
Route::post("/countries/{country}/mccs/reassign", [\App\Http\Controllers\CountryMccController::class, "reassign"])
    ->middleware(["auth","admin"]) ->name("countries.mccs.reassign");
Route::middleware(['auth', \App\Http\Middleware\AdminOnly::class])->group(function () {
    Route::get('networks/duplicates', [NetworkDedupController::class, 'index'])->name('networks.duplicates.index');
    Route::post('networks/duplicates/merge', [NetworkDedupController::class, 'merge'])->name('networks.duplicates.merge');
});

/*
|--------------------------------------------------------------------------
| Suppliers
|--------------------------------------------------------------------------
*/

use App\Http\Controllers\SuppliersController;

Route::middleware(['auth'])->group(function () {
    Route::resource('suppliers', SuppliersController::class)->except(['show']);
});

Route::middleware(['auth'])->group(function () {
    Route::prefix('suppliers/{supplier}')->name('suppliers.')->group(function () {
        Route::get('connections/create', [SupplierConnectionsController::class, 'create'])->name('connections.create');
        Route::post('connections', [SupplierConnectionsController::class, 'store'])->name('connections.store');
        Route::get('connections/{connection}/edit', [SupplierConnectionsController::class, 'edit'])->name('connections.edit');
        Route::put('connections/{connection}', [SupplierConnectionsController::class, 'update'])->name('connections.update');
        Route::delete('connections/{connection}', [SupplierConnectionsController::class, 'destroy'])->name('connections.destroy');
    });
});
