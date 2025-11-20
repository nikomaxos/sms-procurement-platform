
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\CountryLookupController;

Route::get('/countries/search', [CountryLookupController::class, 'search']);
Route::get('/countries/{id}/mccs', [CountryLookupController::class, 'mccs']);
