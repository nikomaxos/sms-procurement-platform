<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Country;

class CountriesController extends Controller
{
    public function index(Request $r)
    {
        $per = max(1, min(1000, (int)$r->integer('per', 20)));
        $countries = Country::with('mccs')->orderBy('name','asc')->paginate($per);
        return view('countries.index', compact('countries'));
    }

    public function edit(Country $country)
    {
        $country->load('mccs');
        $mccs = $country->mccs->pluck('mcc')->all(); // array for implode
        return view('countries.edit', compact('country','mccs'));
    }
}
