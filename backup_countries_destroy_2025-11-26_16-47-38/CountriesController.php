<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Country;

class CountriesController extends Controller
{
    public function update(\Illuminate\Http\Request $request, \App\Models\Country $country) {
        $data = $request->validate([
            "name" => ["required","string","max:255"],
            "iso2" => ["nullable","string","size:2"],
        ]);
        if(isset($data["iso2"])) { $data["iso2"] = strtolower($data["iso2"]); }
        $country->fill($data); $country->save();
        return redirect()->route("countries.edit", $country)->with("status", "Country updated.");
    }

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

    /**
     * Show the form for creating a new country.
     */
    public function create()
    {
        $country = new \App\Models\Country();

        return view('countries.create', compact('country'));
    }

    /**
     * Store a newly created country from the simple create form.
     */
    public function storeSimple(\Illuminate\Http\Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'iso2' => 'nullable|string|max:2',
        ]);

        $country = new \App\Models\Country();
        $country->name = $data['name'];
        if (!empty($data['iso2'])) {
            $country->iso2 = strtoupper($data['iso2']);
        }
        $country->save();

        return redirect()
            ->route('countries.index')
            ->with('status', 'Country created.');
    }

    /**
     * Store a newly created country.
     */
    public function store(\Illuminate\Http\Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'iso2' => 'nullable|string|max:2',
        ]);

        $country = new \App\Models\Country();
        $country->name = $data['name'];

        if (!empty($data['iso2'])) {
            $country->iso2 = strtoupper($data['iso2']);
        }

        $country->save();

        return redirect()
            ->route('countries.index')
            ->with('status', 'Country created.');
    }
}
