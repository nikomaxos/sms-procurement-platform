<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Country;

class CountryUpdateProxy extends Controller
{
    public function __invoke(Request $request, Country $country)
    {
        $data = $request->validate([
            'name' => ['required','string','max:255'],
            'iso2' => ['nullable','string','size:2'],
        ]);

        if (array_key_exists('iso2', $data) && $data['iso2'] !== null) {
            $data['iso2'] = strtolower($data['iso2']);
        }

        $country->fill($data)->save();

        return redirect()
            ->route('countries.edit', $country)
            ->with('status', 'Country updated.');
    }
}
