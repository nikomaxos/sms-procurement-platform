#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/network_mnc_crud_v1_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/network_mnc_crud_v1_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR"      | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE"     | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

declare -a MOD_FILES=()

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

  echo "==> Rollback complete. See $LOG_FILE for details." | tee -a "$LOG_FILE"
  exit 1
}

trap 'rollback' ERR

NET_CTRL="$ROOT_DIR/app/Http/Controllers/NetworksController.php"
EDIT_VIEW="$ROOT_DIR/resources/views/networks/edit.blade.php"

if [ ! -f "$NET_CTRL" ]; then
  echo "ERROR: NetworksController not found at $NET_CTRL" | tee -a "$LOG_FILE"
  exit 1
fi

if [ ! -f "$EDIT_VIEW" ]; then
  echo "ERROR: networks edit view not found at $EDIT_VIEW" | tee -a "$LOG_FILE"
  exit 1
fi

backup_file "$NET_CTRL"
backup_file "$EDIT_VIEW"

echo "==> Rewriting NetworksController with MNC add/remove support" | tee -a "$LOG_FILE"

cat > "$NET_CTRL" <<'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\Country;
use App\Models\Network;
use App\Models\NetworkMeta;
use App\Models\NetworkMnc;
use App\Support\MccMncNormalizer;
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
        if ($perPage > 200) {
            $perPage = 200;
        }

        $query = Network::query()
            ->with('country')
            ->withCount('mncs')
            ->orderBy('name');

        if ($q !== '') {
            $query->where('name', 'ilike', '%' . $q . '%');
        }

        if (!empty($countryId)) {
            $query->where('country_id', $countryId);
        }

        // CSV export (keeps basic filters; Blade does its own heavy query anyway)
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
            'country_id'      => 'required|integer|exists:countries,id',
            'name'            => 'required|string|max:255',
            'notes'           => 'nullable|string',
            'non_operational' => 'nullable',
            'mncs'            => 'array',
            'mncs.*.mcc'      => 'nullable|string',
            'mncs.*.mnc'      => 'nullable|string',
        ]);

        $network = new Network();
        $network->country_id = (int) $data['country_id'];
        $network->name       = $data['name'];

        if (schema_has_column('networks', 'lower_name')) {
            $network->lower_name = Str::lower($data['name']);
        }

        $network->save();

        // meta: notes + non-operational
        $notes = isset($data['notes']) ? trim((string) $data['notes']) : '';
        $nonOperational = $request->boolean('non_operational');

        if ($notes !== '' || $nonOperational) {
            $meta = NetworkMeta::firstOrNew(['network_id' => $network->id]);
            $meta->non_operational = $nonOperational;
            $meta->notes           = $notes !== '' ? $notes : null;
            $meta->save();
        }

        // MNCs CRUD
        $this->syncMncs($network, $data['mncs'] ?? []);

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
            'country_id'      => 'required|integer|exists:countries,id',
            'name'            => 'required|string|max:255',
            'notes'           => 'nullable|string',
            'non_operational' => 'nullable',
            'mncs'            => 'array',
            'mncs.*.mcc'      => 'nullable|string',
            'mncs.*.mnc'      => 'nullable|string',
        ]);

        $network->country_id = (int) $data['country_id'];
        $network->name       = $data['name'];

        if (schema_has_column('networks', 'lower_name')) {
            $network->lower_name = Str::lower($data['name']);
        }

        $network->save();

        // meta: notes + non-operational
        $notes = isset($data['notes']) ? trim((string) $data['notes']) : '';
        $nonOperational = $request->boolean('non_operational');

        $meta = NetworkMeta::firstOrNew(['network_id' => $network->id]);
        $meta->non_operational = $nonOperational;
        $meta->notes           = $notes !== '' ? $notes : null;

        if ($notes === '' && !$nonOperational && $meta->exists) {
            $meta->notes = null;
        }

        $meta->save();

        // MNCs CRUD
        $this->syncMncs($network, $data['mncs'] ?? []);

        return back()->with('status', 'Network saved.');
    }

    /**
     * Sync MCC/MNC rows for a network from a simple array:
     * mncs[n][mcc], mncs[n][mnc]
     */
    protected function syncMncs(Network $network, ?array $mncs): void
    {
        if (!is_array($mncs)) {
            $mncs = [];
        }

        $normalized = [];

        foreach ($mncs as $row) {
            if (!is_array($row)) {
                continue;
            }

            $mcc = isset($row['mcc']) ? preg_replace('/\D/', '', (string) $row['mcc']) : '';
            $mnc = isset($row['mnc']) ? preg_replace('/\D/', '', (string) $row['mnc']) : '';

            if ($mcc === '' || $mnc === '') {
                continue;
            }

            $mcc = str_pad($mcc, 3, '0', STR_PAD_LEFT);
            $mncKey = str_pad($mnc, 3, '0', STR_PAD_LEFT);

            $key = $mcc . '-' . $mncKey;

            $normalized[$key] = [
                'mcc' => (int) $mcc,
                'mnc' => (int) $mnc,
            ];
        }

        $existing = NetworkMnc::where('network_id', $network->id)->get();
        $existingByKey = [];

        foreach ($existing as $m) {
            $mcc = str_pad((string) $m->mcc, 3, '0', STR_PAD_LEFT);
            $mncKey = str_pad((string) $m->mnc, 3, '0', STR_PAD_LEFT);
            $existingByKey[$mcc . '-' . $mncKey] = $m;
        }

        // Delete removed
        foreach ($existingByKey as $key => $m) {
            if (!array_key_exists($key, $normalized)) {
                $m->delete();
            }
        }

        $userId = optional(auth()->user())->id;

        // Create new or update existing
        foreach ($normalized as $key => $row) {
            if (isset($existingByKey[$key])) {
                $m = $existingByKey[$key];
                if ($userId) {
                    $m->updated_by_user_id = $userId;
                }
                $m->updated_by_source = 'networks.edit';
                $m->save();
                continue;
            }

            $mccInt = $row['mcc'];
            $mncInt = $row['mnc'];
            $raw = sprintf('%03d%03d', $mccInt, $mncInt);

            $mccMnc = class_exists(MccMncNormalizer::class)
                ? MccMncNormalizer::normalize($raw)
                : $raw;

            $m = new NetworkMnc();
            $m->network_id = $network->id;
            $m->mcc = $mccInt;
            $m->mnc = $mncInt;
            $m->mcc_mnc = $mccMnc;
            $m->marked_for_deletion = false;

            if ($userId) {
                $m->created_by_user_id = $userId;
                $m->updated_by_user_id = $userId;
            }

            $m->created_by_source = 'networks.edit';
            $m->updated_by_source = 'networks.edit';

            $m->save();
        }
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

echo "==> NetworksController rewritten." | tee -a "$LOG_FILE"

echo "==> Rewriting networks edit view with editable MCC/MNC table" | tee -a "$LOG_FILE"

cat > "$EDIT_VIEW" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Edit Network: {{ $network->name }}
        </h2>
    </x-slot>

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
        @includeIf('partials.flash_log')

        {{-- Main edit form --}}
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

                {{-- MCC/MNC editable table --}}
                <div class="mt-8 space-y-3">
                    <div class="flex items-center justify-between">
                        <h3 class="text-lg font-semibold text-gray-900">
                            MCC / MNCs
                        </h3>
                        <button
                            type="button"
                            id="add-mnc-row"
                            class="inline-flex items-center rounded-md border border-gray-300 bg-white px-3 py-1.5 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50"
                        >
                            + Add MCC/MNC
                        </button>
                    </div>

                    @php
                        $oldMncs = old('mncs');
                        $rows = [];

                        if (is_array($oldMncs)) {
                            foreach ($oldMncs as $idx => $row) {
                                $rows[] = [
                                    'mcc' => $row['mcc'] ?? '',
                                    'mnc' => $row['mnc'] ?? '',
                                ];
                            }
                        } else {
                            foreach ($network->mncs as $mnc) {
                                $rows[] = [
                                    'mcc' => str_pad((string) $mnc->mcc, 3, '0', STR_PAD_LEFT),
                                    'mnc' => str_pad((string) $mnc->mnc, 2, '0', STR_PAD_LEFT),
                                ];
                            }
                        }
                    @endphp

                    <div class="overflow-x-auto">
                        <table id="mncs-table" class="min-w-full divide-y divide-gray-200 text-sm">
                            <thead class="bg-gray-50">
                                <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                                    <th class="px-4 py-2">MCC</th>
                                    <th class="px-4 py-2">MNC</th>
                                    <th class="px-4 py-2 w-24 text-right">Actions</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-gray-200">
                                @forelse ($rows as $idx => $row)
                                    <tr data-row="1">
                                        <td class="px-4 py-2">
                                            <input
                                                type="text"
                                                name="mncs[{{ $idx }}][mcc]"
                                                value="{{ $row['mcc'] }}"
                                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs font-mono"
                                                placeholder="MCC (3 digits)"
                                            >
                                        </td>
                                        <td class="px-4 py-2">
                                            <input
                                                type="text"
                                                name="mncs[{{ $idx }}][mnc]"
                                                value="{{ $row['mnc'] }}"
                                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs font-mono"
                                                placeholder="MNC (2-3 digits)"
                                            >
                                        </td>
                                        <td class="px-4 py-2 text-right">
                                            <button
                                                type="button"
                                                class="js-remove-mnc-row inline-flex items-center rounded-md border border-gray-300 bg-white px-2 py-1 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50"
                                            >
                                                Remove
                                            </button>
                                        </td>
                                    </tr>
                                @empty
                                    {{-- will be filled by JS with an empty row --}}
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                    <p class="text-xs text-gray-500">
                        Leave a row completely empty to ignore it. Removing a row will delete that MCC/MNC from this network when you save.
                    </p>
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

    <script>
        (function () {
            var tableBody = document.querySelector('#mncs-table tbody');
            if (!tableBody) return;

            var addBtn = document.getElementById('add-mnc-row');
            var rows   = tableBody.querySelectorAll('tr[data-row]');
            var index  = rows.length;

            function addRow(mcc, mnc) {
                if (mcc === undefined) mcc = '';
                if (mnc === undefined) mnc = '';

                var tr = document.createElement('tr');
                tr.setAttribute('data-row', '1');

                tr.innerHTML =
                    '<td class="px-4 py-2">' +
                        '<input type="text" name="mncs[' + index + '][mcc]" value="' + mcc + '"' +
                        ' class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs font-mono"' +
                        ' placeholder="MCC (3 digits)">' +
                    '</td>' +
                    '<td class="px-4 py-2">' +
                        '<input type="text" name="mncs[' + index + '][mnc]" value="' + mnc + '"' +
                        ' class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs font-mono"' +
                        ' placeholder="MNC (2-3 digits)">' +
                    '</td>' +
                    '<td class="px-4 py-2 text-right">' +
                        '<button type="button" class="js-remove-mnc-row inline-flex items-center rounded-md border border-gray-300 bg-white px-2 py-1 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50">' +
                            'Remove' +
                        '</button>' +
                    '</td>';

                tableBody.appendChild(tr);
                index += 1;
            }

            if (!tableBody.querySelector('tr[data-row]')) {
                addRow('', '');
            }

            if (addBtn) {
                addBtn.addEventListener('click', function () {
                    addRow('', '');
                });
            }

            tableBody.addEventListener('click', function (e) {
                var btn = e.target.closest('.js-remove-mnc-row');
                if (!btn) return;

                var tr = btn.closest('tr');
                if (tr) {
                    tr.remove();
                }
            });
        })();
    </script>
</x-app-layout>
BLADE

echo "==> networks/edit.blade.php rewritten with editable MNC rows." | tee -a "$LOG_FILE"

echo "==> Clearing & rebuilding view cache (best-effort)..." | tee -a "$LOG_FILE"

if command -v docker >/dev/null 2>&1 && docker compose ps >/dev/null 2>&1; then
  SERVICE=""
  if docker compose ps --services 2>/dev/null | grep -qx "app"; then
    SERVICE="app"
  elif docker compose ps --services 2>/dev/null | grep -qx "sms-platform-app"; then
    SERVICE="sms-platform-app"
  fi

  if [ -n "$SERVICE" ]; then
    echo "   - Using docker compose exec $SERVICE" | tee -a "$LOG_FILE"
    docker compose exec -T "$SERVICE" php artisan optimize:clear | tee -a "$LOG_FILE" || true
    docker compose exec -T "$SERVICE" php artisan view:cache       | tee -a "$LOG_FILE" || true
  else
    echo "   - No matching artisan service found; skipping docker artisan commands." | tee -a "$LOG_FILE"
  fi
else
  echo "   - docker compose not available; skipping artisan commands." | tee -a "$LOG_FILE"
fi

trap - ERR

echo "==> network_mnc_crud_v1.sh completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE"            | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
