<?php
$F = 'app/Http/Controllers/CountryMccController.php';
$c = file_get_contents($F);
if ($c === false) { fwrite(STDERR,"Cannot read $F\n"); exit(1); }

if (strpos($c, 'function reassign(') === false) {
  // ensure imports
  if (strpos($c, 'use Illuminate\\Http\\Request;') === false) {
    $c = preg_replace('/^<\?php\s+namespace App\\\\Http\\\\Controllers;/', "<?php\nnamespace App\\Http\\Controllers;\n\nuse Illuminate\\Http\\Request;", $c, 1);
  }
  if (strpos($c, 'use Illuminate\\Support\\Facades\\DB;') === false) {
    $c = preg_replace('/^<\?php[^\n]*\nnamespace [^;]+;\n/s', "$0\nuse Illuminate\\Support\\Facades\\DB;\n", $c, 1);
  }
  if (strpos($c, 'use App\\Models\\Country;') === false) {
    $c = preg_replace('/^<\?php[^\n]*\nnamespace [^;]+;\n/s', "$0use App\\Models\\Country;\n", $c, 1);
  }

  $method = <<<'PHPMETHOD'

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
PHPMETHOD;

  // append before last closing brace
  $c = preg_replace('/\}\s*$/', $method."\n}\n", $c, 1);
  file_put_contents($F, $c);
  echo "Patched CountryMccController@reassign\n";
} else {
  echo "CountryMccController@reassign already exists\n";
}
