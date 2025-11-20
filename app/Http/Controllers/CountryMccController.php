<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\Country;

class CountryMccController extends Controller
{
    public function store(Request $request, Country $country)
    {
        $mcc = trim((string)$request->input('mcc',''));
        $log = [];

        // Validate format: exactly 3 digits
        if (!preg_match('/^\d{3}$/', $mcc)) {
            $log[] = "Invalid MCC format: $mcc (must be exactly 3 digits)";
            return back()->with('error','MCC must be exactly 3 digits.')->with('log',$log);
        }

        // Global uniqueness check (country_mccs.mcc is unique)
        $existing = DB::table('country_mccs')->where('mcc', $mcc)->first();

        if ($existing) {
            if ((int)$existing->country_id === (int)$country->id) {
                $log[] = "MCC $mcc already exists for {$country->name}.";
                return back()->with('status','Nothing to change.')->with('log',$log);
            } else {
                $ownerName = optional(Country::find($existing->country_id))->name ?? ("ID {$existing->country_id}");
                $log[] = "MCC $mcc is owned by $ownerName.";
                return back()->with('error',"MCC $mcc already assigned to $ownerName.")->with('log',$log);
            }
        }

        DB::table('country_mccs')->insert([
            'country_id' => $country->id,
            'mcc'        => $mcc,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $log[] = "Added MCC $mcc to {$country->name}.";
        return back()->with('status','MCC added.')->with('log',$log);
    }

    public function destroy(Country $country, string $mcc)
    {
        $log = [];
        $row = DB::table('country_mccs')
            ->where('country_id', $country->id)
            ->where('mcc', $mcc)
            ->first();

        if (!$row) {
            $log[] = "MCC $mcc not found for {$country->name}.";
            return back()->with('error',"MCC $mcc not found for this country.")->with('log',$log);
        }

        DB::table('country_mccs')->where('id', $row->id)->delete();

        $log[] = "Removed MCC $mcc from {$country->name}.";
        return back()->with('status','MCC removed.')->with('log',$log);
    }

    public function reassign(Request $request, Country $country)
    {
        $data = $request->validate([
            'mcc' => ['required','digits:3'],
            'target_country_id' => ['required','integer','different:country.id'],
        ]);

        $mcc      = $data['mcc'];
        $targetId = (int) $data['target_country_id'];
        $log = [];

        $target = Country::find($targetId);
        if (!$target) {
            return back()->with('error', 'Η νέα χώρα δεν βρέθηκε.')->withInput();
        }

        $existing = DB::table('country_mccs')->where('mcc', $mcc)->first();
        if (!$existing) {
            // Δεν υπάρχει καθόλου, απλή εισαγωγή
            DB::table('country_mccs')->insert([
                'country_id' => $targetId,
                'mcc'        => $mcc,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $log[] = "Δημιουργήθηκε MCC {$mcc} για χώρα {$target->name}.";
            return back()->with('status', 'Η μεταφορά ολοκληρώθηκε.')->with('log', $log);
        }

        if ((int)$existing->country_id === $targetId) {
            $log[] = "Το MCC {$mcc} είναι ήδη στη χώρα {$target->name}.";
            return back()->with('status', 'Δεν απαιτείται ενέργεια.')->with('log',$log);
        }

        $prev = Country::find($existing->country_id);
        DB::table('country_mccs')->where('mcc', $mcc)->update([
            'country_id' => $targetId,
            'updated_at' => now(),
        ]);
        $log[] = "Μεταφέρθηκε MCC {$mcc} από ".($prev? $prev->name : ('ID '.$existing->country_id))." → {$target->name}.";
        return back()->with('status', 'Η μεταφορά ολοκληρώθηκε.')->with('log', $log);
    }
}
