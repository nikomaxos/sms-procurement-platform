#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"; b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step5: Networks UI + Controller polish"

############################################
# 1) Model: App\Models\Network
############################################
F=app/Models/Network.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Network extends Model
{
    protected $fillable = ['name','country_id'];
    public $timestamps = true;

    protected static function booted(): void
    {
        static::saving(function (self $model) {
            $model->lower_name = Str::lower((string)$model->name);
        });
    }

    public function country(): BelongsTo
    {
        return $this->belongsTo(\App\Models\Country::class);
    }

    public function mncs(): HasMany
    {
        return $this->hasMany(\App\Models\NetworkMnc::class);
    }

    /** Simple filters for index page */
    public function scopeFilter($q, array $f)
    {
        if (!empty($f['q'])) {
            $s = mb_strtolower(trim((string)$f['q']));
            $q->whereRaw('lower(name) like ?', ['%'.$s.'%']);
        }
        if (!empty($f['country_id']) && ctype_digit((string)$f['country_id'])) {
            $q->where('country_id', (int)$f['country_id']);
        }
        if (!empty($f['mcc'])) {
            $mcc = preg_replace('/\D/','',(string)$f['mcc']);
            if ($mcc !== '') {
                $q->whereHas('mncs', fn($qq)=>$qq->where('mcc',$mcc));
            }
        }
        if (!empty($f['mnc'])) {
            $mnc = preg_replace('/\D/','',(string)$f['mnc']);
            if ($mnc !== '') {
                $q->whereHas('mncs', fn($qq)=>$qq->where('mnc',$mnc));
            }
        }
        return $q;
    }
}
PHP

############################################
# 2) Controller: App\Http\Controllers\NetworksController
############################################
F=app/Http/Controllers/NetworksController.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Str;
use App\Models\Network;
use App\Models\Country;

class NetworksController extends Controller
{
    public function index(Request $request)
    {
        $filters = [
            'q'          => $request->string('q')->toString(),
            'country_id' => $request->input('country_id'),
            'mcc'        => $request->input('mcc'),
            'mnc'        => $request->input('mnc'),
        ];

        $networks = Network::with(['country'])
            ->filter($filters)
            ->orderBy('name')
            ->paginate(20)
            ->withQueryString();

        $countries = Country::orderBy('name')->get(['id','name']);

        return view('networks.index', compact('networks','countries','filters'));
    }

    public function create()
    {
        $countries = Country::orderBy('name')->get(['id','name']);
        $network = new Network();
        return view('networks.create', compact('network','countries'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name'       => ['required','string','max:255'],
            'country_id' => ['required','integer','exists:countries,id'],
        ]);

        // lower(name) unique per country guard (manual due to functional index)
        $exists = Network::where('country_id',$data['country_id'])
            ->whereRaw('lower(name) = ?', [Str::lower($data['name'])])
            ->exists();
        if ($exists) {
            throw ValidationException::withMessages([
                'name' => 'This network already exists in the selected country.',
            ]);
        }

        $network = Network::create($data);

        return redirect()->route('networks.edit',$network->id)
            ->with('status','Network created.');
    }

    public function edit(Network $network)
    {
        $network->load(['country','mncs']);
        $countries = Country::orderBy('name')->get(['id','name']);
        return view('networks.edit', compact('network','countries'));
    }

    public function update(Request $request, Network $network)
    {
        $data = $request->validate([
            'name'       => ['required','string','max:255'],
            'country_id' => ['required','integer','exists:countries,id'],
        ]);

        $exists = Network::where('country_id',$data['country_id'])
            ->whereRaw('lower(name) = ?', [Str::lower($data['name'])])
            ->where('id','<>',$network->id)
            ->exists();
        if ($exists) {
            throw ValidationException::withMessages([
                'name' => 'Another network with the same name already exists in that country.',
            ]);
        }

        $network->fill($data)->save();

        return back()->with('status','Network updated.');
    }

    public function destroy(Network $network)
    {
        $id = $network->id;
        $network->mncs()->delete(); // keep clean; audit already captured in network_mncs if enabled
        $network->delete();
        return redirect()->route('networks.index')->with('status',"Network #$id deleted.");
    }
}
PHP

############################################
# 3) Views
############################################

# 3a) partials/flash_log exists from Step4c; reuse on networks pages
P=resources/views/partials/flash_log.blade.php
[ -f "$P" ] || {
  mkdir -p "$(dirname "$P")"
  cat > "$P" <<'BLADE'
@if (session('status'))
  <div class="mb-3 rounded border border-green-300 bg-green-50 p-3 text-green-800">
    {{ session('status') }}
  </div>
@endif
@if (session('error'))
  <div class="mb-3 rounded border border-red-300 bg-red-50 p-3 text-red-800">
    {{ session('error') }}
  </div>
@endif
@if (session('log'))
  <div class="mb-4 rounded border border-gray-300 bg-gray-50 p-3 text-gray-800">
    <div class="font-semibold mb-1">Log</div>
    <ul class="list-disc ml-5 text-sm">
      @foreach (session('log') as $line)
        <li>{{ $line }}</li>
      @endforeach
    </ul>
  </div>
@endif
BLADE
}

# 3b) networks/index.blade.php
F=resources/views/networks/index.blade.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2>
    </x-slot>

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        @include('partials.flash_log')

        <form method="GET" class="mb-4 grid grid-cols-1 md:grid-cols-5 gap-3">
            <input class="border rounded p-2" type="text" name="q" placeholder="Search name…" value="{{ $filters['q'] ?? '' }}">
            <select class="border rounded p-2" name="country_id">
                <option value="">— Country —</option>
                @foreach ($countries as $c)
                    <option value="{{ $c->id }}" @selected(($filters['country_id'] ?? '') == $c->id)>{{ $c->name }}</option>
                @endforeach
            </select>
            <input class="border rounded p-2" type="text" name="mcc" placeholder="MCC" value="{{ $filters['mcc'] ?? '' }}">
            <input class="border rounded p-2" type="text" name="mnc" placeholder="MNC" value="{{ $filters['mnc'] ?? '' }}">
            <button class="border rounded p-2" type="submit">Filter</button>
        </form>

        <div class="mb-3">
            <a href="{{ route('networks.create') }}" class="inline-block rounded bg-blue-600 text-white px-3 py-2">+ New network</a>
        </div>

        <div class="overflow-x-auto bg-white rounded shadow">
            <table class="min-w-full text-sm">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="text-left p-2">Name</th>
                        <th class="text-left p-2">Country</th>
                        <th class="text-left p-2">MNCs</th>
                        <th class="text-left p-2">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($networks as $n)
                        <tr class="border-t">
                            <td class="p-2">{{ $n->name }}</td>
                            <td class="p-2">{{ $n->country->name ?? '—' }}</td>
                            <td class="p-2">
                                @php $mncs = $n->mncs()->orderBy('mcc')->orderBy('mnc')->limit(10)->get(); @endphp
                                @forelse ($mncs as $link)
                                    <span class="inline-block px-2 py-0.5 text-xs rounded bg-gray-100 border mr-1 mb-1">
                                        {{ $link->mcc }}-{{ $link->mnc }}
                                    </span>
                                @empty
                                    <span class="text-gray-400">none</span>
                                @endforelse
                            </td>
                            <td class="p-2">
                                <a class="text-blue-600 hover:underline mr-3" href="{{ route('networks.edit', $n->id) }}">Edit</a>
                                <form method="POST" action="{{ route('networks.destroy', $n->id) }}" class="inline"
                                      onsubmit="return confirm('Delete this network?');">
                                    @csrf @method('DELETE')
                                    <button class="text-red-600 hover:underline" type="submit">Delete</button>
                                </form>
                            </td>
                        </tr>
                    @empty
                        <tr><td colspan="4" class="p-3 text-center text-gray-500">No results</td></tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div class="mt-4">{{ $networks->links() }}</div>
    </div>
</x-app-layout>
BLADE

# 3c) networks/_form.blade.php
F=resources/views/networks/_form.blade.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'BLADE'
@csrf
<div class="grid grid-cols-1 md:grid-cols-2 gap-3">
    <div>
        <label class="block text-sm font-medium mb-1">Name</label>
        <input class="border rounded w-full p-2" type="text" name="name" value="{{ old('name', $network->name ?? '') }}" required>
        @error('name') <div class="text-red-600 text-sm mt-1">{{ $message }}</div> @enderror
    </div>
    <div>
        <label class="block text-sm font-medium mb-1">Country</label>
        <select class="border rounded w-full p-2" name="country_id" required>
            <option value="">— Select —</option>
            @foreach ($countries as $c)
                <option value="{{ $c->id }}" @selected(old('country_id', $network->country_id ?? '') == $c->id)>{{ $c->name }}</option>
            @endforeach
        </select>
        @error('country_id') <div class="text-red-600 text-sm mt-1">{{ $message }}</div> @enderror
    </div>
</div>
BLADE

# 3d) networks/create.blade.php
F=resources/views/networks/create.blade.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">New Network</h2>
    </x-slot>

    <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        @include('partials.flash_log')

        <form method="POST" action="{{ route('networks.store') }}" class="bg-white rounded shadow p-4">
            @include('networks._form', ['network' => $network, 'countries' => $countries])
            <div class="mt-4">
                <button class="rounded bg-blue-600 text-white px-4 py-2" type="submit">Create</button>
                <a class="ml-3 text-gray-600 hover:underline" href="{{ route('networks.index') }}">Cancel</a>
            </div>
        </form>
    </div>
</x-app-layout>
BLADE

# 3e) networks/edit.blade.php
F=resources/views/networks/edit.blade.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Network</h2>
    </x-slot>

    <div class="py-6 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        @include('partials.flash_log')

        <form method="POST" action="{{ route('networks.update', $network->id) }}" class="bg-white rounded shadow p-4 mb-6">
            @method('PUT')
            @include('networks._form', ['network' => $network, 'countries' => $countries])
            <div class="mt-4">
                <button class="rounded bg-blue-600 text-white px-4 py-2" type="submit">Save</button>
                <a class="ml-3 text-gray-600 hover:underline" href="{{ route('networks.index') }}">Back</a>
            </div>
        </form>

        <div class="bg-white rounded shadow p-4">
            <div class="font-semibold mb-2">MNCs</div>

            <form class="mb-3 flex gap-2" method="POST" action="{{ route('networks.mncs.store', $network->id) }}">
                @csrf
                <input class="border rounded p-2 w-24" type="text" name="mcc" placeholder="MCC" required>
                <input class="border rounded p-2 w-24" type="text" name="mnc" placeholder="MNC" required>
                <button class="rounded bg-gray-800 text-white px-3 py-2" type="submit">Add</button>
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
# 4) Cache warm + lint
############################################
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l app/Models/Network.php
  php -l app/Http/Controllers/NetworksController.php
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'
echo "==> Step5 complete."
