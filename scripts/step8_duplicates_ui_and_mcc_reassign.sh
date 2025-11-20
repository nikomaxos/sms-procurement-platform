#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"; b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step8: Duplicates UI (admin) + MCC reassign flow"

mkdir -p app/Http/Controllers resources/views/networks tools/patches

############################################
# 1) NetworkDedupController (admin UI)
############################################
CTRL=app/Http/Controllers/NetworkDedupController.php
b "$CTRL"
cat > "$CTRL" <<'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Services\NetworkMergeService;
use App\Models\Country;
use App\Models\Network;

class NetworkDedupController extends Controller
{
    public function __construct()
    {
        $this->middleware(['auth','admin']);
    }

    public function index(Request $request, NetworkMergeService $svc)
    {
        $countryId = $request->query('country_id');
        $countries = Country::orderBy('name')->get(['id','name']);
        $groups = $svc->findDuplicateGroups($countryId ? (int)$countryId : null);

        // εμπλουτισμός με αναλυτικά networks & mncs_count
        $details = [];
        foreach ($groups as $g) {
            $networks = Network::withCount('mncs')
                ->whereIn('id', $g['ids'])
                ->orderBy('id')
                ->get(['id','name','country_id']);
            $country = $countries->firstWhere('id', $g['country_id']);
            $details[] = [
                'country_id'   => $g['country_id'],
                'country_name' => $country?->name ?? ('#'.$g['country_id']),
                'lower_name'   => $g['lower_name'],
                'networks'     => $networks,
            ];
        }

        return view('networks.duplicates', [
            'countries'  => $countries,
            'countryId'  => $countryId,
            'groups'     => $details,
        ]);
    }

    public function merge(Request $request, NetworkMergeService $svc)
    {
        $data = $request->validate([
            'country_id'  => ['required','integer'],
            'lower_name'  => ['required','string'],
            'survivor_id' => ['nullable','integer'],
            'action'      => ['required','in:preview,apply'],
        ]);

        $dry  = $data['action'] === 'preview';
        $res  = $svc->mergeGroup((int)$data['country_id'], $data['lower_name'], $data['survivor_id'] ?? null, $dry);

        $log = array_merge($res['notes'] ?? [], [
            'Moved MNC rows: '.$res['moved'],
            'Deleted loser networks: '.$res['deleted'],
            'Survivor ID: '.$res['survivor']
        ]);

        return back()
            ->with($dry ? 'status' : 'success', $dry ? 'Προεπισκόπηση ολοκληρώθηκε.' : 'Συγχώνευση ολοκληρώθηκε.')
            ->with('log', $log)
            ->withInput();
    }
}
PHP

############################################
# 2) View: resources/views/networks/duplicates.blade.php
############################################
VIEW=resources/views/networks/duplicates.blade.php
b "$VIEW"
cat > "$VIEW" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <div class="flex items-center justify-between">
      <h2 class="font-semibold text-xl text-gray-800 leading-tight">
        Διπλοεγγραφές Δικτύων (ανά Χώρα & όνομα)
      </h2>
      <a href="{{ route('networks.index') }}" class="text-sm px-3 py-1.5 rounded bg-gray-100 hover:bg-gray-200">← Πίσω στα Δίκτυα</a>
    </div>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
    @if (session('success'))
      <div class="bg-green-100 text-green-800 p-3 rounded">{{ session('success') }}</div>
    @endif
    @if (session('status'))
      <div class="bg-blue-100 text-blue-800 p-3 rounded">{{ session('status') }}</div>
    @endif>
    @if (session('error'))
      <div class="bg-red-100 text-red-800 p-3 rounded">{{ session('error') }}</div>
    @endif
    @if (session('log'))
      <details open class="bg-white border rounded p-3">
        <summary class="cursor-pointer font-medium">Log ενεργειών</summary>
        <ul class="list-disc pl-5 mt-2">
          @foreach((array) session('log') as $line)
            <li>{{ $line }}</li>
          @endforeach
        </ul>
      </details>
    @endif

    <form method="GET" class="flex flex-wrap gap-3 items-end">
      <div>
        <label class="block text-sm font-medium mb-1">Φίλτρο χώρας</label>
        <select name="country_id" class="border rounded p-2">
          <option value="">— Όλες —</option>
          @foreach($countries as $c)
            <option value="{{ $c->id }}" @selected($countryId==$c->id)>{{ $c->name }} ({{ $c->id }})</option>
          @endforeach
        </select>
      </div>
      <div>
        <button class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">Ανανέωση</button>
      </div>
    </form>

    @if (empty($groups))
      <div class="bg-white border rounded p-6 text-gray-600">Δεν βρέθηκαν διπλοεγγραφές.</div>
    @else
      @foreach($groups as $g)
        <div class="bg-white border rounded p-4 space-y-3">
          <div class="flex flex-wrap items-center gap-3">
            <div class="text-lg font-semibold">{{ $g['country_name'] }} (ID {{ $g['country_id'] }})</div>
            <div class="text-gray-600">όνομα: <span class="font-mono px-2 py-0.5 bg-gray-100 rounded">{{ $g['lower_name'] }}</span></div>
          </div>

          <form method="POST" action="{{ route('networks.duplicates.merge') }}" class="space-y-2">
            @csrf
            <input type="hidden" name="country_id" value="{{ $g['country_id'] }}">
            <input type="hidden" name="lower_name" value="{{ $g['lower_name'] }}">

            <table class="min-w-full text-sm border">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-2 py-1 text-left">Survivor;</th>
                  <th class="px-2 py-1 text-left">Network ID</th>
                  <th class="px-2 py-1 text-left">Name</th>
                  <th class="px-2 py-1 text-left">MNCs</th>
                </tr>
              </thead>
              <tbody>
                @php $default = $g['networks']->min('id'); @endphp
                @foreach($g['networks'] as $n)
                  <tr class="border-t">
                    <td class="px-2 py-1">
                      <input type="radio" name="survivor_id" value="{{ $n->id }}" @checked($n->id===$default)>
                    </td>
                    <td class="px-2 py-1 font-mono">{{ $n->id }}</td>
                    <td class="px-2 py-1">{{ $n->name }}</td>
                    <td class="px-2 py-1">{{ $n->mncs_count }}</td>
                  </tr>
                @endforeach
              </tbody>
            </table>

            <div class="flex gap-2 pt-2">
              <button name="action" value="preview" class="px-3 py-2 rounded bg-gray-100 hover:bg-gray-200">Προεπισκόπηση</button>
              <button name="action" value="apply"   class="px-3 py-2 rounded bg-red-600 text-white hover:bg-red-700"
                      onclick="return confirm('Σίγουρα; Θα μετακινηθούν MNCs και θα διαγραφούν οι losers.');">
                Συγχώνευση
              </button>
            </div>
          </form>
        </div>
      @endforeach
    @endif
  </div>
</x-app-layout>
BLADE

############################################
# 3) CountryMccController@reassign (admin)
############################################
PHPEDIT=tools/patches/add_reassign_to_country_mcc.php
cat > "$PHPEDIT" <<'PHP'
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
PHP
php "$PHPEDIT"

############################################
# 4) Routes
############################################
ROUTES=routes/web.php
b "$ROUTES"
php -r '
$F="routes/web.php"; $c=file_get_contents($F);
$needA = (strpos($c,"networks.duplicates.index")===false);
$needB = (strpos($c,"countries.mccs.reassign")===false);
$add = "";
if($needA){
  $add .= "\n// === Networks Duplicates (admin) ===\n";
  $add .= "Route::middleware([\"auth\",\"admin\"])->prefix(\"networks\")->name(\"networks.\")->group(function(){\n";
  $add .= "    Route::get(\"/duplicates\", [\\App\\Http\\Controllers\\NetworkDedupController::class, \"index\"])->name(\"duplicates.index\");\n";
  $add .= "    Route::post(\"/duplicates/merge\", [\\App\\Http\\Controllers\\NetworkDedupController::class, \"merge\"])->name(\"duplicates.merge\");\n";
  $add .= "});\n";
}
if($needB){
  $add .= "\n// === Country MCC reassign (admin) ===\n";
  $add .= "Route::post(\"/countries/{country}/mccs/reassign\", [\\App\\Http\\Controllers\\CountryMccController::class, \"reassign\"])\n";
  $add .= "    ->middleware([\"auth\",\"admin\"]) ->name(\"countries.mccs.reassign\");\n";
}
if($add){ file_put_contents($F, $c.$add); echo "Routes appended\n"; } else { echo "Routes already present\n"; }
'

############################################
# 5) Add “Μεταφορά MCC” panel into countries/edit.blade.php (append)
############################################
EDITVIEW=resources/views/countries/edit.blade.php
b "$EDITVIEW"
cat >> "$EDITVIEW" <<'BLADE'

{{-- ===== Step8: Μεταφορά MCC σε άλλη χώρα (Admin) ===== --}}
<div class="mt-8 p-4 border rounded bg-white">
  <h3 class="font-semibold mb-2">Μεταφορά MCC σε άλλη χώρα</h3>

  @if (session('error'))
    <div class="bg-red-100 text-red-800 text-sm p-2 rounded mb-2">{{ session('error') }}</div>
  @endif
  @if (session('status'))
    <div class="bg-green-100 text-green-800 text-sm p-2 rounded mb-2">{{ session('status') }}</div>
  @endif
  @if (session('log'))
    <details open class="mb-3">
      <summary class="cursor-pointer font-medium">Λεπτομέρειες</summary>
      <ul class="list-disc pl-5">
        @foreach((array) session('log') as $line)
          <li>{{ $line }}</li>
        @endforeach
      </ul>
    </details>
  @endif

  @php
    $mccRows = \Illuminate\Support\Facades\DB::table('country_mccs')->where('country_id',$country->id)->orderBy('mcc')->get();
    $allCountries = \App\Models\Country::orderBy('name')->get();
  @endphp

  <form method="POST" action="{{ route('countries.mccs.reassign', ['country'=>$country->id]) }}" class="grid grid-cols-1 md:grid-cols-3 gap-3">
    @csrf
    <div>
      <label class="block text-sm font-medium mb-1">MCC προς μεταφορά</label>
      <select name="mcc" class="border rounded w-full p-2" required>
        <option value="" disabled selected>— επίλεξε MCC —</option>
        @foreach($mccRows as $r)
          <option value="{{ $r->mcc }}">{{ $r->mcc }}</option>
        @endforeach
      </select>
    </div>
    <div>
      <label class="block text-sm font-medium mb-1">Νέα χώρα</label>
      <select name="target_country_id" class="border rounded w-full p-2" required>
        <option value="" disabled selected>— επίλεξε χώρα —</option>
        @foreach($allCountries as $c)
          <option value="{{ $c->id }}">{{ $c->name }} ({{ $c->id }})</option>
        @endforeach
      </select>
    </div>
    <div class="flex items-end">
      <button class="px-3 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">Μεταφορά</button>
    </div>
  </form>
</div>
BLADE

############################################
# 6) Warm caches and show new routes
############################################
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l app/Http/Controllers/NetworkDedupController.php
  php -l app/Http/Controllers/CountryMccController.php
  php -l -d detect_unicode=0 $(git ls-files "*.php" | tr "\n" " ") >/dev/null || true
  php artisan optimize:clear
  php artisan config:cache
  php artisan route:cache
  php artisan view:cache
  php artisan route:list | grep -E "networks\.duplicates|countries\.mccs\.reassign" || true
'
echo "==> Step8 done. Open: /networks/duplicates  (admin only)  ή /countries/{id}/edit για panel μεταφοράς MCC."
