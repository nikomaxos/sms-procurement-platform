#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/network_notes_meta_v2_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/network_notes_meta_v2_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR"            | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE"           | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR"       | tee -a "$LOG_FILE"

declare -a MOD_FILES=()
declare -a NEW_FILES=()

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    mkdir -p "$(dirname "$backup_path")" 2>/dev/null || true
    cp "$f" "$backup_path"
    MOD_FILES+=("$f")
    echo "==> Backed up $f -> $backup_path" | tee -a "$LOG_FILE"
  fi
}

rollback() {
  echo "==> ERROR: Rolling back changes..." | tee -a "$LOG_FILE"

  for f in "${MOD_FILES[@]}"; do
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    if [ -f "$backup_path" ]; then
      cp "$backup_path" "$f"
      echo "   - Restored $f from $backup_path" | tee -a "$LOG_FILE"
    fi
  done

  for f in "${NEW_FILES[@]}"; do
    if [ -f "$f" ]; then
      rm -f "$f"
      echo "   - Removed new file $f" | tee -a "$LOG_FILE"
    fi
  done

  echo "==> Rollback complete. See $LOG_FILE for details." | tee -a "$LOG_FILE"
  exit 1
}

trap 'rollback' ERR

# Ensure we are in repo root
cd "$ROOT_DIR"

########################################
# 1) Rewrite Network model
########################################
NET_MODEL="$ROOT_DIR/app/Models/Network.php"
backup_file "$NET_MODEL"

cat > "$NET_MODEL" <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Str;

class Network extends Model
{
    protected $fillable = [
        'name',
        'country_id',
    ];

    public $timestamps = true;

    protected static function booted(): void
    {
        static::saving(function (self $model): void {
            $model->lower_name = Str::lower((string) $model->name);
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

    public function meta(): HasOne
    {
        return $this->hasOne(\App\Models\NetworkMeta::class);
    }

    /**
     * Simple filters for index page.
     */
    public function scopeFilter($query, array $filters)
    {
        if (!empty($filters['q'])) {
            $search = mb_strtolower(trim((string) $filters['q']));
            $query->whereRaw('lower(name) like ?', ['%' . $search . '%']);
        }

        if (!empty($filters['country_id']) && ctype_digit((string) $filters['country_id'])) {
            $query->where('country_id', (int) $filters['country_id']);
        }

        if (!empty($filters['mcc'])) {
            $mcc = preg_replace('/\D/', '', (string) $filters['mcc']);
            if ($mcc !== '') {
                $query->whereHas('mncs', function ($q) use ($mcc) {
                    $q->where('mcc', $mcc);
                });
            }
        }

        if (!empty($filters['mnc'])) {
            $mnc = preg_replace('/\D/', '', (string) $filters['mnc']);
            if ($mnc !== '') {
                $query->whereHas('mncs', function ($q) use ($mnc) {
                    $q->where('mnc', $mnc);
                });
            }
        }

        return $query;
    }
}
PHP

echo "==> Network model rewritten with meta() relation." | tee -a "$LOG_FILE"

########################################
# 2) NetworkMeta model
########################################
NET_META_MODEL="$ROOT_DIR/app/Models/NetworkMeta.php"
if [ -f "$NET_META_MODEL" ]; then
  backup_file "$NET_META_MODEL"
else
  NEW_FILES+=("$NET_META_MODEL")
fi

cat > "$NET_META_MODEL" <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMeta extends Model
{
    protected $table = 'network_meta';

    protected $fillable = [
        'network_id',
        'non_operational',
        'notes',
    ];

    protected $casts = [
        'non_operational' => 'bool',
    ];

    public function network(): BelongsTo
    {
        return $this->belongsTo(Network::class);
    }
}
PHP

echo "==> NetworkMeta model written." | tee -a "$LOG_FILE"

########################################
# 3) Rewrite NetworksController
########################################
NET_CTRL="$ROOT_DIR/app/Http/Controllers/NetworksController.php"
backup_file "$NET_CTRL"

cat > "$NET_CTRL" <<'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\Country;
use App\Models\Network;
use App\Models\NetworkMeta;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class NetworksController extends Controller
{
    public function index(Request $request)
    {
        $q         = trim((string) $request->query('q', ''));
        $countryId = $request->query('country_id');
        $perPage   = (int) $request->query('per_page', 20);

        if ($perPage < 5) {
            $perPage = 5;
        }
        if ($perPage > 100) {
            $perPage = 100;
        }

        $query = Network::query()
            ->with('country')
            ->withCount('mncs')
            ->orderBy('name');

        if ($q !== '') {
            // Postgres case-insensitive search
            $query->where('name', 'ilike', '%' . $q . '%');
        }

        if (!empty($countryId)) {
            $query->where('country_id', $countryId);
        }

        // CSV export (respects filters)
        if ($request->query('export') === 'csv') {
            $rows = $query->get(['id', 'country_id', 'name']);

            $map = DB::table('network_mncs')
                ->select([
                    'network_id',
                    DB::raw("string_agg(DISTINCT mcc::text, ',' ORDER BY mcc::text) as mccs"),
                    DB::raw("string_agg((mcc::text||'-'||mnc::text), ',' ORDER BY mcc,mnc) as pairs"),
                    DB::raw('count(*) as mnc_count'),
                ])
                ->whereIn('network_id', $rows->pluck('id'))
                ->groupBy('network_id')
                ->get()
                ->keyBy('network_id');

            $countries = DB::table('countries')
                ->whereIn('id', $rows->pluck('country_id'))
                ->pluck('name', 'id');

            $filename = 'networks_export_' . date('Ymd_His') . '.csv';

            return response()->streamDownload(function () use ($rows, $map, $countries) {
                $out = fopen('php://output', 'w');
                fputcsv($out, ['Network ID', 'Name', 'Country', 'MCCs', 'MNC count', 'MCC-MNC pairs']);

                foreach ($rows as $r) {
                    $a = $map[$r->id] ?? null;
                    fputcsv($out, [
                        $r->id,
                        $r->name,
                        $countries[$r->country_id] ?? '',
                        $a->mccs ?? '',
                        $a->mnc_count ?? 0,
                        $a->pairs ?? '',
                    ]);
                }

                fclose($out);
            }, $filename, [
                'Content-Type'  => 'text/csv',
                'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
            ]);
        }

        $networks = $query->paginate($perPage)->appends($request->query());

        // light MCC aggregation for current page (kept for legacy)
        $ids = $networks->getCollection()->pluck('id');
        $mccsMap = DB::table('network_mncs')
            ->select('network_id', DB::raw("string_agg(DISTINCT mcc::text, ',' ORDER BY mcc::text) as mccs"))
            ->whereIn('network_id', $ids)
            ->groupBy('network_id')
            ->pluck('mccs', 'network_id');

        $filters = [
            'q'            => $q,
            'country_id'   => $countryId,
            'country_name' => $countryId ? (DB::table('countries')->where('id', $countryId)->value('name') ?? '') : '',
            'per_page'     => $perPage,
        ];

        // New Blade does its own query; these vars are harmless extras.
        return view('networks.index', [
            'networks' => $networks,
            'mccsMap'  => $mccsMap,
            'filters'  => $filters,
        ]);
    }

    public function create()
    {
        $network   = new Network();
        $countries = Country::orderBy('name')->get();

        return view('networks.create', compact('network', 'countries'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'country_id'       => 'required|integer|exists:countries,id',
            'name'             => 'required|string|max:255',
            'notes'            => 'nullable|string',
            'non_operational'  => 'nullable',
        ]);

        $network = new Network();
        $network->country_id = (int) $data['country_id'];
        $network->name       = $data['name'];

        // keep lower_name consistent with unique index
        if (schema_has_column('networks', 'lower_name')) {
            $network->lower_name = Str::lower($data['name']);
        }

        $network->save();

        // Handle meta (notes + non_operational)
        $notes = isset($data['notes']) ? trim((string) $data['notes']) : '';
        $nonOperational = $request->boolean('non_operational');

        if ($notes !== '' || $nonOperational) {
            $meta = NetworkMeta::firstOrNew(['network_id' => $network->id]);
            $meta->non_operational = $nonOperational;
            $meta->notes           = $notes !== '' ? $notes : null;
            $meta->save();
        }

        return redirect()
            ->route('networks.edit', $network->id)
            ->with('status', 'Network created.');
    }

    public function edit(Network $network)
    {
        $network->load('country', 'mncs', 'meta');
        $countries = Country::orderBy('name')->get();

        return view('networks.edit', compact('network', 'countries'));
    }

    public function update(Request $request, Network $network)
    {
        $data = $request->validate([
            'country_id'       => 'required|integer|exists:countries,id',
            'name'             => 'required|string|max:255',
            'notes'            => 'nullable|string',
            'non_operational'  => 'nullable',
        ]);

        $network->country_id = (int) $data['country_id'];
        $network->name       = $data['name'];

        if (schema_has_column('networks', 'lower_name')) {
            $network->lower_name = Str::lower($data['name']);
        }

        $network->save();

        // Handle meta (notes + non_operational)
        $notes = isset($data['notes']) ? trim((string) $data['notes']) : '';
        $nonOperational = $request->boolean('non_operational');

        $meta = NetworkMeta::firstOrNew(['network_id' => $network->id]);
        $meta->non_operational = $nonOperational;
        $meta->notes           = $notes !== '' ? $notes : null;

        if ($notes === '' && !$nonOperational && $meta->exists) {
            // we clear notes but keep the row (helps for explicit operational flags)
            $meta->notes = null;
        }

        $meta->save();

        return back()->with('status', 'Network saved.');
    }
}

/**
 * Tiny helper: check if a column exists (Postgres-safe).
 */
if (!function_exists('schema_has_column')) {
    function schema_has_column(string $table, string $column): bool
    {
        try {
            return \Illuminate\Support\Facades\Schema::hasColumn($table, $column);
        } catch (\Throwable $e) {
            return false;
        }
    }
}
PHP

echo "==> NetworksController rewritten cleanly with notes handling." | tee -a "$LOG_FILE"

########################################
# 4) Rewrite networks edit view
########################################
EDIT_VIEW="$ROOT_DIR/resources/views/networks/edit.blade.php"
backup_file "$EDIT_VIEW"

cat > "$EDIT_VIEW" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Edit Network: {{ $network->name }}
        </h2>
    </x-slot>

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        @includeIf('partials.flash_log')

        <div class="bg-white shadow sm:rounded-lg p-6 space-y-6">
            <form method="POST" action="{{ route('networks.update', $network->id) }}">
                @csrf
                @method('PUT')

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    {{-- Country --}}
                    <div>
                        <label for="country_id" class="block text-sm font-medium text-gray-700">
                            Country
                        </label>
                        <select
                            id="country_id"
                            name="country_id"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            required
                        >
                            @foreach ($countries as $country)
                                <option value="{{ $country->id }}" @selected($country->id === $network->country_id)>
                                    {{ $country->name }} ({{ $country->iso2 }})
                                </option>
                            @endforeach
                        </select>
                        @error('country_id')
                            <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    {{-- Name --}}
                    <div>
                        <label for="name" class="block text-sm font-medium text-gray-700">
                            Name
                        </label>
                        <input
                            type="text"
                            id="name"
                            name="name"
                            value="{{ old('name', $network->name) }}"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            required
                        >
                        @error('name')
                            <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
                    {{-- Non-operational flag --}}
                    <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                            Status
                        </label>
                        <div class="flex items-center gap-2">
                            <input
                                type="checkbox"
                                id="non_operational"
                                name="non_operational"
                                value="1"
                                class="rounded border-gray-300 text-indigo-600 shadow-sm focus:ring-indigo-500"
                                @checked(optional($network->meta)->non_operational)
                            >
                            <label for="non_operational" class="text-sm text-gray-700">
                                Mark as non-operational
                            </label>
                        </div>
                    </div>

                    {{-- Notes --}}
                    <div>
                        <label for="notes" class="block text-sm font-medium text-gray-700">
                            Notes
                        </label>
                        <textarea
                            id="notes"
                            name="notes"
                            rows="4"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            placeholder="Internal notes about this network (e.g. outages, roaming only, special routing)..."
                        >{{ old('notes', optional($network->meta)->notes) }}</textarea>
                        @error('notes')
                            <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                <div class="mt-6 flex items-center justify-end gap-3">
                    <a
                        href="{{ route('networks.index') }}"
                        class="inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50"
                    >
                        Back to list
                    </a>

                    <button
                        type="submit"
                        class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                    >
                        Save
                    </button>
                </div>
            </form>
        </div>
    </div>
</x-app-layout>
BLADE

echo "==> networks/edit.blade.php rewritten with Notes + Non-operational." | tee -a "$LOG_FILE"

########################################
# 5) Clear & rebuild caches
########################################
echo "==> Clearing & rebuilding Laravel caches..." | tee -a "$LOG_FILE"

if command -v docker >/dev/null 2>&1 && docker compose ps >/dev/null 2>&1; then
  if docker compose ps app >/dev/null 2>&1; then
    APP_SERVICE="app"
  else
    APP_SERVICE="sms-platform-app"
  fi
  echo "   - Using docker compose exec ${APP_SERVICE} for artisan" | tee -a "$LOG_FILE"
  docker compose exec -T "${APP_SERVICE}" php artisan optimize:clear   | tee -a "$LOG_FILE" || true
  docker compose exec -T "${APP_SERVICE}" php artisan view:cache       | tee -a "$LOG_FILE" || true
else
  echo "   - docker compose not available or not in this directory; skipping artisan cache clear." | tee -a "$LOG_FILE"
fi

trap - ERR

echo "==> network_notes_meta_v2.sh completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
