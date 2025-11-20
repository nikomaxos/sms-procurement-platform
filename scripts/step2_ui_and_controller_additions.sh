#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Step2: UI & small controllers for MCC/MNC management (chips + add/remove)"

mkdir -p app/Http/Controllers resources/views/countries resources/views/networks resources/views/carriers

############################################
# 1) CountryMccController (add/remove MCC)
############################################
F=app/Http/Controllers/CountryMccController.php
b "$F"
cat > "$F" <<'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\Country;

class CountryMccController extends Controller
{
    public function store(Request $request, Country $country)
    {
        $data = $request->validate([
            'mcc' => ['required','digits:3']
        ]);
        $mcc = $data['mcc'];

        return DB::transaction(function () use ($country, $mcc) {
            $existing = DB::table('country_mccs')->where('mcc', $mcc)->first();
            if ($existing && (int)$existing->country_id !== (int)$country->id) {
                // Reassign MCC to this country (dataset-level uniqueness of MCC)
                DB::table('country_mccs')->where('id', $existing->id)->update([
                    'country_id' => $country->id,
                    'updated_at' => now(),
                ]);
                return back()->with('warning', "MCC $mcc reassigned from country ID {$existing->country_id} to {$country->id}.");
            }

            DB::table('country_mccs')->updateOrInsert(
                ['mcc' => $mcc],
                ['country_id' => $country->id, 'updated_at' => now(), 'created_at' => now()]
            );

            return back()->with('success', "MCC $mcc added.");
        });
    }

    public function destroy(Country $country, string $mcc)
    {
        if (!ctype_digit($mcc) || strlen($mcc) !== 3) {
            return back()->with('error', 'Invalid MCC.');
        }
        $deleted = DB::table('country_mccs')
            ->where('country_id', $country->id)
            ->where('mcc', $mcc)
            ->delete();

        return back()->with($deleted ? 'success' : 'info', $deleted ? "MCC $mcc removed." : "MCC $mcc not found for this country.");
    }
}
PHP

############################################
# 2) NetworkMncController (add/remove MCC/MNC)
############################################
F=app/Http/Controllers/NetworkMncController.php
b "$F"
cat > "$F" <<'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\Network;

class NetworkMncController extends Controller
{
    public function store(Request $request, Network $network)
    {
        $data = $request->validate([
            'mcc' => ['required','digits:3'],
            'mnc' => ['required','regex:/^\d{1,3}$/'],
        ]);
        $mcc = $data['mcc'];
        $mnc = ltrim($data['mnc'], ' '); // trim whitespace
        $mncPadded = str_pad($mnc, 3, '0', STR_PAD_LEFT);
        $mcc_mnc = $mcc . $mncPadded;

        return DB::transaction(function () use ($network, $mcc, $mnc, $mcc_mnc) {
            $existing = DB::table('network_mncs')->where('mcc', $mcc)->where('mnc', $mnc)->first();

            if ($existing) {
                if ((int)$existing->network_id !== (int)$network->id) {
                    DB::table('network_mncs')->where('id', $existing->id)->update([
                        'network_id' => $network->id,
                        'mcc_mnc'    => $mcc_mnc,
                        'updated_at' => now(),
                    ]);
                    return back()->with('warning', "Pair $mcc/$mnc reassigned from network ID {$existing->network_id} to {$network->id}.");
                }
                return back()->with('info', "Pair $mcc/$mnc already exists on this network.");
            }

            DB::table('network_mncs')->insert([
                'network_id' => $network->id,
                'mcc'        => $mcc,
                'mnc'        => $mnc,
                'mcc_mnc'    => $mcc_mnc,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            return back()->with('success', "Pair $mcc/$mnc added.");
        });
    }

    public function destroy(Network $network, string $mcc, string $mnc)
    {
        if (!ctype_digit($mcc) || strlen($mcc)!==3 || !ctype_digit($mnc) || strlen($mnc) > 3) {
            return back()->with('error', 'Invalid MCC/MNC.');
        }

        $deleted = DB::table('network_mncs')
            ->where('network_id', $network->id)
            ->where('mcc', $mcc)
            ->where('mnc', $mnc)
            ->delete();

        return back()->with($deleted ? 'success' : 'info', $deleted ? "Pair $mcc/$mnc removed." : "Pair $mcc/$mnc not found on this network.");
    }
}
PHP

############################################
# 3) Views
############################################

# 3a) Countries edit with MCC chips + add/remove
V=resources/views/countries/edit.blade.php
b "$V"
cat > "$V" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Country — {{ $country->name }}</h2>
  </x-slot>

  <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('success')) <div class="mb-4 p-3 rounded bg-green-50 text-green-700">{{ session('success') }}</div> @endif
    @if (session('warning')) <div class="mb-4 p-3 rounded bg-yellow-50 text-yellow-700">{{ session('warning') }}</div> @endif
    @if (session('error'))   <div class="mb-4 p-3 rounded bg-red-50 text-red-700">{{ session('error') }}</div> @endif
    @if (session('info'))    <div class="mb-4 p-3 rounded bg-blue-50 text-blue-700">{{ session('info') }}</div> @endif

    {{-- Basic fields --}}
    <form method="POST" action="{{ route('countries.update', $country->id) }}" class="bg-white rounded-lg shadow p-6 mb-8">
      @csrf @method('PUT')
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <label class="block">
          <span class="text-sm text-gray-600">Name</span>
          <input name="name" value="{{ old('name', $country->name) }}" class="mt-1 w-full border rounded p-2" required>
          @error('name')<div class="text-red-600 text-sm mt-1">{{ $message }}</div>@enderror
        </label>
        <label class="block">
          <span class="text-sm text-gray-600">ISO2</span>
          <input name="iso2" value="{{ old('iso2', $country->iso2 ?? '') }}" class="mt-1 w-full border rounded p-2" maxlength="2">
          @error('iso2')<div class="text-red-600 text-sm mt-1">{{ $message }}</div>@enderror
        </label>
      </div>
      <div class="mt-4">
        <button class="px-4 py-2 rounded bg-indigo-600 text-white hover:bg-indigo-700">Save</button>
        <a href="{{ route('countries.index') }}" class="ml-2 text-gray-600 hover:underline">Back</a>
      </div>
    </form>

    {{-- MCC management --}}
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="font-semibold mb-3">Mobile Country Codes (MCCs)</h3>

      @php
        // Expecting $mccs as array; if not present, compute safely
        $mccs = (isset($mccs) && is_array($mccs)) ? $mccs
              : \Illuminate\Support\Facades\DB::table('country_mccs')->where('country_id', $country->id)->orderBy('mcc')->pluck('mcc')->toArray();
      @endphp

      <div class="flex flex-wrap gap-2 mb-4">
        @forelse($mccs as $m)
          <span class="inline-flex items-center gap-2 bg-gray-100 rounded px-2 py-1 text-sm">
            <span class="font-mono">{{ $m }}</span>
            <form method="POST" action="{{ route('countries.mccs.destroy', [$country->id, $m]) }}" onsubmit="return confirm('Remove MCC {{ $m }}?')">
              @csrf @method('DELETE')
              <button class="text-red-600 hover:text-red-800" title="Remove">&times;</button>
            </form>
          </span>
        @empty
          <span class="text-gray-500">No MCCs yet.</span>
        @endforelse
      </div>

      <form method="POST" action="{{ route('countries.mccs.store', $country->id) }}" class="flex items-end gap-3">
        @csrf
        <label>
          <span class="block text-sm text-gray-600">Add MCC</span>
          <input name="mcc" maxlength="3" class="border rounded p-2 w-24" placeholder="202" value="{{ old('mcc') }}">
        </label>
        <button class="px-3 py-2 rounded bg-gray-800 text-white hover:bg-black">Add</button>
      </form>
      @error('mcc')<div class="text-red-600 text-sm mt-2">{{ $message }}</div>@enderror
    </div>
  </div>
</x-app-layout>
BLADE

# 3b) Networks index with filters and MCC list
V=resources/views/networks/index.blade.php
b "$V"
cat > "$V" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <form method="GET" class="grid grid-cols-1 md:grid-cols-5 gap-2 mb-4 bg-white p-4 rounded-lg shadow">
      <input name="q" value="{{ request('q') }}" placeholder="Search name…" class="border rounded p-2">
      <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC" class="border rounded p-2">
      <input name="mnc" value="{{ request('mnc') }}" placeholder="MNC" class="border rounded p-2">
      <select name="country" class="border rounded p-2">
        <option value="">All countries</option>
        @php
          $countries = $countries ?? \Illuminate\Support\Facades\DB::table('countries')->orderBy('name')->get();
        @endphp
        @foreach($countries as $c)
          <option value="{{ $c->id }}" @selected((string)request('country') === (string)$c->id)>{{ $c->name }}</option>
        @endforeach
      </select>
      <button class="px-3 py-2 rounded bg-indigo-600 text-white hover:bg-indigo-700">Filter</button>
    </form>

    <div class="bg-white rounded-lg shadow overflow-hidden">
      <table class="min-w-full">
        <thead class="bg-gray-50 text-left">
          <tr>
            <th class="px-4 py-2">Country</th>
            <th class="px-4 py-2">Network</th>
            <th class="px-4 py-2">MCCs</th>
            <th class="px-4 py-2">MNC Count</th>
            <th class="px-4 py-2">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          @forelse($networks as $n)
            @php
              $mncs = \Illuminate\Support\Facades\DB::table('network_mncs')
                        ->where('network_id', $n->id)
                        ->orderBy('mcc')->orderBy('mnc')->get(['mcc','mnc']);
              $mccs = $mncs->pluck('mcc')->unique()->values()->all();
            @endphp
            <tr>
              <td class="px-4 py-2 text-sm text-gray-700">{{ $n->country->name ?? \Illuminate\Support\Facades\DB::table('countries')->where('id',$n->country_id)->value('name') }}</td>
              <td class="px-4 py-2">{{ $n->name }}</td>
              <td class="px-4 py-2 text-sm">
                @if (count($mccs))
                  <span class="font-mono">{{ implode(', ', $mccs) }}</span>
                @else
                  <span class="text-gray-400">—</span>
                @endif
              </td>
              <td class="px-4 py-2 text-sm">{{ $mncs->count() }}</td>
              <td class="px-4 py-2">
                <a href="{{ route('networks.edit', $n->id) }}" class="text-indigo-600 hover:underline">Edit</a>
              </td>
            </tr>
          @empty
            <tr><td colspan="5" class="px-4 py-6 text-center text-gray-500">No networks found.</td></tr>
          @endforelse
        </tbody>
      </table>
    </div>

    <div class="mt-4">
      {{ $networks->withQueryString()->links() }}
    </div>
  </div>
</x-app-layout>
BLADE

# 3c) Networks edit with MCC/MNC management
V=resources/views/networks/edit.blade.php
b "$V"
cat > "$V" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network — {{ $network->name }}</h2>
  </x-slot>

  <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('success')) <div class="mb-4 p-3 rounded bg-green-50 text-green-700">{{ session('success') }}</div> @endif
    @if (session('warning')) <div class="mb-4 p-3 rounded bg-yellow-50 text-yellow-700">{{ session('warning') }}</div> @endif
    @if (session('error'))   <div class="mb-4 p-3 rounded bg-red-50 text-red-700">{{ session('error') }}</div> @endif
    @if (session('info'))    <div class="mb-4 p-3 rounded bg-blue-50 text-blue-700">{{ session('info') }}</div> @endif

    {{-- Basic network form --}}
    <form method="POST" action="{{ route('networks.update', $network->id) }}" class="bg-white rounded-lg shadow p-6 mb-8">
      @csrf @method('PUT')
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <label class="block">
          <span class="text-sm text-gray-600">Name</span>
          <input name="name" value="{{ old('name', $network->name) }}" class="mt-1 w-full border rounded p-2" required>
          @error('name')<div class="text-red-600 text-sm mt-1">{{ $message }}</div>@enderror
        </label>
        <label class="block">
          <span class="text-sm text-gray-600">Country</span>
          <select name="country_id" class="mt-1 w-full border rounded p-2">
            @php
              $countries = \Illuminate\Support\Facades\DB::table('countries')->orderBy('name')->get(['id','name']);
            @endphp
            @foreach($countries as $c)
              <option value="{{ $c->id }}" @selected((int)$network->country_id === (int)$c->id)>{{ $c->name }}</option>
            @endforeach
          </select>
          @error('country_id')<div class="text-red-600 text-sm mt-1">{{ $message }}</div>@enderror
        </label>
      </div>
      <div class="mt-4">
        <button class="px-4 py-2 rounded bg-indigo-600 text-white hover:bg-indigo-700">Save</button>
        <a href="{{ route('networks.index') }}" class="ml-2 text-gray-600 hover:underline">Back</a>
      </div>
    </form>

    {{-- MCC/MNC management --}}
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="font-semibold mb-4">MCC/MNC pairs</h3>

      @php
        $mncs = \Illuminate\Support\Facades\DB::table('network_mncs')
                  ->where('network_id', $network->id)
                  ->orderBy('mcc')->orderBy('mnc')->get(['mcc','mnc']);
      @endphp

      <table class="min-w-full mb-4">
        <thead class="bg-gray-50 text-left">
          <tr>
            <th class="px-4 py-2">MCC</th>
            <th class="px-4 py-2">MNC</th>
            <th class="px-4 py-2">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          @forelse($mncs as $row)
            <tr>
              <td class="px-4 py-2 font-mono">{{ $row->mcc }}</td>
              <td class="px-4 py-2 font-mono">{{ $row->mnc }}</td>
              <td class="px-4 py-2">
                <form method="POST" action="{{ route('networks.mncs.destroy', [$network->id, $row->mcc, $row->mnc]) }}" onsubmit="return confirm('Delete {{ $row->mcc }}/{{ $row->mnc }}?')">
                  @csrf @method('DELETE')
                  <button class="text-red-600 hover:underline">Delete</button>
                </form>
              </td>
            </tr>
          @empty
            <tr><td colspan="3" class="px-4 py-6 text-center text-gray-500">No pairs yet.</td></tr>
          @endforelse
        </tbody>
      </table>

      <form method="POST" action="{{ route('networks.mncs.store', $network->id) }}" class="flex items-end gap-3">
        @csrf
        <label>
          <span class="block text-sm text-gray-600">MCC</span>
          <input name="mcc" maxlength="3" class="border rounded p-2 w-24" placeholder="202" value="{{ old('mcc') }}">
        </label>
        <label>
          <span class="block text-sm text-gray-600">MNC</span>
          <input name="mnc" maxlength="3" class="border rounded p-2 w-24" placeholder="10" value="{{ old('mnc') }}">
        </label>
        <button class="px-3 py-2 rounded bg-gray-800 text-white hover:bg-black">Add</button>
      </form>
      @error('mcc')<div class="text-red-600 text-sm mt-2">{{ $message }}</div>@enderror
      @error('mnc')<div class="text-red-600 text-sm mt-2">{{ $message }}</div>@enderror
    </div>
  </div>
</x-app-layout>
BLADE

# 3d) Minimal carriers import page
V=resources/views/carriers/import.blade.php
b "$V"
cat > "$V" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Carriers Import</h2>
  </x-slot>

  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('success')) <div class="mb-4 p-3 rounded bg-green-50 text-green-700">{{ session('success') }}</div> @endif
    @if (session('warning')) <div class="mb-4 p-3 rounded bg-yellow-50 text-yellow-700">{{ session('warning') }}</div> @endif
    @if (session('error'))   <div class="mb-4 p-3 rounded bg-red-50 text-red-700">{{ session('error') }}</div> @endif

    <form method="POST" action="{{ route('carriers.import') }}" class="bg-white rounded-lg shadow p-6">
      @csrf
      <label class="inline-flex items-center gap-2">
        <input type="checkbox" name="fresh" class="rounded">
        <span>Fresh import (truncate links first)</span>
      </label>
      <div class="mt-4">
        <button class="px-4 py-2 rounded bg-indigo-600 text-white hover:bg-indigo-700">Run import</button>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

############################################
# 4) Routes additions (auth-protected)
############################################
R=routes/web.php
b "$R"

# Remove any prior duplicates for our new names to avoid clutter
sed -i '/countries\.mccs\./d' "$R" || true
sed -i '/networks\.mncs\./d' "$R" || true

cat >> "$R" <<'PHP'

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
PHP

############################################
# 5) Cache warm & route check
############################################
$DC exec -T app sh -lc '
  set -e
  php -l app/Http/Controllers/CountryMccController.php
  php -l app/Http/Controllers/NetworkMncController.php
  php -l resources/views/countries/edit.blade.php >/dev/null || true
  php -l resources/views/networks/index.blade.php >/dev/null || true
  php -l resources/views/networks/edit.blade.php  >/dev/null || true
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
  php artisan route:list | grep -E "countries/.*/mccs|networks/.*/mncs|carriers/import" -n || true
'

echo "==> Step2 complete."
