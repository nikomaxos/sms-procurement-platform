#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"; b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step5b: Country search-as-you-type + MCC readonly from country"

############################################
# 1) API Controller (search & mccs)
############################################
mkdir -p app/Http/Controllers/Api
F=app/Http/Controllers/Api/CountryLookupController.php
b "$F"
cat > "$F" <<'PHP'
<?php
namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CountryLookupController extends Controller
{
    public function search(Request $request)
    {
        $q = mb_strtolower(trim((string)$request->query('q','')));
        $limit = (int)($request->query('limit', 20));
        $rows = DB::table('countries')
            ->when($q !== '', fn($qq)=>$qq->whereRaw('lower(name) like ?', ['%'.$q.'%']))
            ->orderBy('name')
            ->limit($limit)
            ->get(['id','name']);

        // attach MCCs for each country (array of strings)
        $ids = $rows->pluck('id')->all();
        $mccMap = DB::table('country_mccs')
            ->whereIn('country_id', $ids)
            ->orderBy('mcc')
            ->get(['country_id','mcc'])
            ->groupBy('country_id')
            ->map(fn($g)=>$g->pluck('mcc')->values()->all());

        $out = $rows->map(function($r) use ($mccMap){
            return [
                'id'   => $r->id,
                'name' => $r->name,
                'mccs' => $mccMap[$r->id] ?? [],
            ];
        });

        return response()->json($out);
    }

    public function mccs($countryId)
    {
        $mccs = DB::table('country_mccs')
            ->where('country_id', (int)$countryId)
            ->orderBy('mcc')
            ->pluck('mcc')
            ->values()
            ->all();

        return response()->json(['country_id' => (int)$countryId, 'mccs' => $mccs]);
    }
}
PHP

############################################
# 2) routes/api.php
############################################
R=routes/api.php
if ! grep -q "CountryLookupController" "$R" 2>/dev/null; then
  b "$R"
  cat >> "$R" <<'PHP'

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\CountryLookupController;

Route::get('/countries/search', [CountryLookupController::class, 'search']);
Route::get('/countries/{id}/mccs', [CountryLookupController::class, 'mccs']);
PHP
fi

############################################
# 3) Views: make Country search-as-you-type & MCC readonly
############################################

# 3a) networks/_form.blade.php (χώρα: search-as-you-type, MCC: readonly)
F=resources/views/networks/_form.blade.php
b "$F"
cat > "$F" <<'BLADE'
@csrf
<div x-data="networkForm({
        initialCountryId: {{ old('country_id', $network->country_id ?? 'null') }},
        initialCountryName: @json(old('country_name', $network->country->name ?? '')),
})" class="grid grid-cols-1 md:grid-cols-2 gap-3">
    <input type="hidden" name="country_id" x-model="countryId">
    <div class="md:col-span-1">
        <label class="block text-sm font-medium mb-1">Χώρα</label>
        <div class="relative">
            <input x-model="query"
                   @input.debounce.200ms="search()"
                   @focus="open=true"
                   @keydown.escape="open=false"
                   class="border rounded w-full p-2"
                   type="text"
                   placeholder="Αναζήτηση χώρας..."
                   :value="countryName"
                   @change.prevent
            >
            <template x-if="open && results.length">
                <div class="absolute z-10 mt-1 w-full bg-white border rounded shadow max-h-64 overflow-auto">
                    <template x-for="item in results" :key="item.id">
                        <div class="px-3 py-2 hover:bg-gray-50 cursor-pointer"
                             @click="selectCountry(item)">
                            <span x-text="item.name"></span>
                            <template x-if="item.mccs.length">
                                <span class="ml-2 text-xs text-gray-500" x-text="'MCC: '+item.mccs.join(', ')"></span>
                            </template>
                        </div>
                    </template>
                </div>
            </template>
        </div>
        @error('country_id') <div class="text-red-600 text-sm mt-1">{{ $message }}</div> @enderror
    </div>

    <div class="md:col-span-1">
        <label class="block text-sm font-medium mb-1">MCC (μόνο από χώρα)</label>
        <input class="border rounded w-full p-2 bg-gray-100"
               type="text"
               :value="selectedMcc || (mccs.length ? mccs[0] : '')"
               readonly>
        <div class="mt-2">
            <template x-if="mccs.length > 1">
                <div>
                    <span class="text-xs text-gray-500 mr-2">Επιλογή MCC:</span>
                    <template x-for="m in mccs" :key="m">
                        <button type="button"
                                class="inline-block px-2 py-1 text-xs rounded border mr-1 mb-1"
                                :class="m===selectedMcc ? 'bg-gray-800 text-white' : 'bg-gray-100'"
                                @click="selectedMcc = m">
                            <span x-text="m"></span>
                        </button>
                    </template>
                </div>
            </template>
        </div>
        <input type="hidden" name="selected_mcc" x-model="selectedMcc">
    </div>

    <div class="md:col-span-2">
        <label class="block text-sm font-medium mb-1">Name</label>
        <input class="border rounded w-full p-2" type="text" name="name" value="{{ old('name', $network->name ?? '') }}" required>
        @error('name') <div class="text-red-600 text-sm mt-1">{{ $message }}</div> @enderror
    </div>
</div>

<!-- Alpine helpers (inline, no external libs) -->
<script>
document.currentScript && (function(){
  window.networkForm = function(cfg){
    return {
      query: cfg.initialCountryName || '',
      open: false,
      results: [],
      countryId: cfg.initialCountryId || null,
      countryName: cfg.initialCountryName || '',
      mccs: [],
      selectedMcc: null,
      async fetchMccs(countryId){
        try{
          const r = await fetch(`/api/countries/${countryId}/mccs`);
          if(!r.ok) return;
          const j = await r.json();
          this.mccs = Array.isArray(j.mccs) ? j.mccs : [];
          if (!this.mccs.includes(this.selectedMcc)) this.selectedMcc = this.mccs[0] || null;
        }catch(e){}
      },
      async search(){
        if(!this.query || this.query.length < 1){ this.results=[]; return; }
        try{
          const r = await fetch(`/api/countries/search?q=${encodeURIComponent(this.query)}&limit=20`);
          if(!r.ok) return;
          this.results = await r.json();
        }catch(e){}
      },
      selectCountry(item){
        this.countryId = item.id;
        this.countryName = item.name;
        this.query = item.name;
        this.open = false;
        this.results = [];
        this.mccs = Array.isArray(item.mccs) ? item.mccs : [];
        this.selectedMcc = this.mccs[0] || null;
      },
      async init(){
        if(this.countryId){
          await this.fetchMccs(this.countryId);
          if(!this.countryName) {
            // best-effort reverse lookup to show name in input
            try{
              const r = await fetch(`/api/countries/search?q=&limit=1&country_id=${this.countryId}`);
            }catch(e){}
          }
        }
      }
    }
  }
})();
</script>
BLADE

# 3b) networks/create.blade.php: τύλιγμα με Alpine root
F=resources/views/networks/create.blade.php
b "$F"
cat > "$F" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">New Network</h2>
    </x-slot>

    <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8" x-data>
        @include('partials.flash_log')

        <form method="POST" action="{{ route('networks.store') }}" class="bg-white rounded shadow p-4">
            @include('networks._form', ['network' => $network, 'countries' => []])
            <div class="mt-4">
                <button class="rounded bg-blue-600 text-white px-4 py-2" type="submit">Create</button>
                <a class="ml-3 text-gray-600 hover:underline" href="{{ route('networks.index') }}">Cancel</a>
            </div>
        </form>
    </div>
</x-app-layout>
BLADE

# 3c) networks/edit.blade.php: Alpine root + χρήση MCC (readonly) για Add MNC
F=resources/views/networks/edit.blade.php
b "$F"
cat > "$F" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2>
    </x-slot>

    <div class="py-6 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8" x-data>
        @include('partials.flash_log')

        <form method="POST" action="{{ route('networks.update', $network->id) }}" class="bg-white rounded shadow p-4 mb-6">
            @method('PUT')
            @include('networks._form', ['network' => $network, 'countries' => []])
            <div class="mt-4">
                <button class="rounded bg-blue-600 text-white px-4 py-2" type="submit">Save</button>
                <a class="ml-3 text-gray-600 hover:underline" href="{{ route('networks.index') }}">Back</a>
            </div>
        </form>

        <div class="bg-white rounded shadow p-4" x-data>
            <div class="font-semibold mb-2">MNCs</div>

            <form class="mb-3 flex flex-wrap items-center gap-2" method="POST" action="{{ route('networks.mncs.store', $network->id) }}">
                @csrf
                <!-- MCC readonly from selected country -->
                <div>
                    <label class="block text-xs text-gray-500 mb-1">MCC</label>
                    <input class="border rounded p-2 w-28 bg-gray-100" type="text"
                           x-bind:value="document.querySelector('[name=selected_mcc]')?.value || ''"
                           readonly>
                    <input type="hidden" name="mcc"
                           x-bind:value="document.querySelector('[name=selected_mcc]')?.value || ''">
                </div>
                <div>
                    <label class="block text-xs text-gray-500 mb-1">MNC</label>
                    <input class="border rounded p-2 w-24" type="text" name="mnc" placeholder="MNC" required>
                </div>
                <div>
                    <button class="rounded bg-gray-800 text-white px-3 py-2"
                            type="submit"
                            x-bind:disabled="!(document.querySelector('[name=selected_mcc]')?.value)">
                        Add
                    </button>
                </div>
            </form>

            <div>
                @php $links = $network->mncs()->orderBy('mcc')->orderBy('mnc')->get(); @endphp
                @forelse ($links as $link)
                    <form method="POST" class="inline-block mr-2 mb-2"
                          action="{{ route('networks.mncs.destroy', [$network->id, $link->mcc, $link->mnc]) }}">
                        @csrf @method('DELETE')
                        <button class="inline-flex items-center gap-2 px-2 py-1 text-xs rounded bg-gray-100 border"
                                title="Remove"
                                onclick="return confirm('Remove {{ $link->mcc }}-{{ $link->mnc }} ?');">
                            {{ $link->mcc }}-{{ $link->mnc }}
                            <span aria-hidden="true">✕</span>
                        </button>
                    </form>
                @empty
                    <span class="text-gray-400">No MNCs</span>
                @endforelse
            </div>
        </div>
    </div>
</x-app-layout>
BLADE

############################################
# 4) Warm caches & lint
############################################
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l app/Http/Controllers/Api/CountryLookupController.php
  php -l resources/views/networks/_form.blade.php
  php -l resources/views/networks/create.blade.php
  php -l resources/views/networks/edit.blade.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
'
echo "==> Step5b done."
