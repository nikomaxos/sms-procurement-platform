#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/mnc_full_pipeline_v1_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/mnc_full_pipeline_v1_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR"      | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE"     | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

# Track modified / new files for rollback
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

register_new_file() {
  local f="$1"
  NEW_FILES+=("$f")
  echo "==> Will treat $f as NEW (remove on rollback)" | tee -a "$LOG_FILE"
}

ARTISAN_SERVICE=""

detect_artisan_service() {
  ARTISAN_SERVICE=""
  if command -v docker >/dev/null 2>&1 && docker compose ps >/dev/null 2>&1; then
    if docker compose ps --services 2>/dev/null | grep -qx "app"; then
      ARTISAN_SERVICE="app"
    elif docker compose ps --services 2>/dev/null | grep -qx "sms-platform-app"; then
      ARTISAN_SERVICE="sms-platform-app"
    fi
  fi
}

run_artisan() {
  local cmd="$1"
  if [ -n "$ARTISAN_SERVICE" ]; then
    echo "   - docker compose exec -T ${ARTISAN_SERVICE} ${cmd}" | tee -a "$LOG_FILE"
    docker compose exec -T "$ARTISAN_SERVICE" $cmd | tee -a "$LOG_FILE"
  else
    echo "   - No artisan service detected; attempting local '${cmd}'" | tee -a "$LOG_FILE"
    (cd "$ROOT_DIR" && $cmd) | tee -a "$LOG_FILE"
  fi
}

rollback() {
  echo "==> ERROR: Rolling back changes..." | tee -a "$LOG_FILE"

  # Try to rollback the last migration step (best-effort)
  detect_artisan_service
  if [ -n "$ARTISAN_SERVICE" ]; then
    echo "   - Attempting php artisan migrate:rollback --step=1" | tee -a "$LOG_FILE"
    docker compose exec -T "$ARTISAN_SERVICE" php artisan migrate:rollback --step=1 2>&1 | tee -a "$LOG_FILE" || true
  else
    echo "   - No artisan service detected for migrate:rollback; skipping DB rollback." | tee -a "$LOG_FILE"
  fi

  # Restore modified files
  for f in "${MOD_FILES[@]}"; do
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    if [ -f "$backup_path" ]; then
      cp "$backup_path" "$f"
      echo "   - Restored $f from $backup_path" | tee -a "$LOG_FILE"
    fi
  done

  # Remove new files
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

NORMALIZER="$ROOT_DIR/app/Support/MccMncNormalizer.php"
NETWORK_MNC="$ROOT_DIR/app/Models/NetworkMnc.php"
NET_INDEX="$ROOT_DIR/resources/views/networks/index.blade.php"

if [ ! -f "$NETWORK_MNC" ]; then
  echo "ERROR: NetworkMnc model not found at $NETWORK_MNC" | tee -a "$LOG_FILE"
  exit 1
fi

if [ ! -f "$NET_INDEX" ]; then
  echo "ERROR: networks index view not found at $NET_INDEX" | tee -a "$LOG_FILE"
  exit 1
fi

# Backups
if [ -f "$NORMALIZER" ]; then
  backup_file "$NORMALIZER"
fi
backup_file "$NETWORK_MNC"
backup_file "$NET_INDEX"

echo "==> Writing App\\Support\\MccMncNormalizer (4th-digit 0 trimming rule)" | tee -a "$LOG_FILE"

cat > "$NORMALIZER" <<'PHP'
<?php

namespace App\Support;

/**
 * Normalize MCC/MNC composite codes.
 *
 * Rules:
 * - Strip all non-digits.
 * - Consider at most 6 digits (MCC(3) + MNC(2-3)).
 * - If we have 6 digits and the 4th digit is '0', drop that '0' => 5-digit code.
 *   Example: 202001 => 20201 (MCC 202, MNC 001 -> MCC 202, MNC 01).
 * - Otherwise: return the digits as-is.
 */
class MccMncNormalizer
{
    public static function normalize(?string $value): string
    {
        $digits = preg_replace('/\D/', '', (string) $value);

        if ($digits === '') {
            return '';
        }

        $len = strlen($digits);

        // Focus on up to 6 digits, as MCC(3) + MNC(2-3)
        if ($len > 6) {
            $digits = substr($digits, 0, 6);
            $len = 6;
        }

        // If 6 digits and the 4th digit (index 3) is '0',
        // drop that '0' so result is 5 digits (MCC + last 2 digits of MNC).
        if ($len === 6 && $digits[3] === '0') {
            return substr($digits, 0, 3) . substr($digits, 4); // 3 + 2 = 5 digits
        }

        // For 5 digits (3+2) or 6 digits (3+3) without the special 0 rule, keep as-is.
        return $digits;
    }
}
PHP

echo "==> Rewriting App\\Models\\NetworkMnc to normalize mcc, mnc, mcc_mnc on save" | tee -a "$LOG_FILE"

cat > "$NETWORK_MNC" <<'PHP'
<?php

namespace App\Models;

use App\Support\MccMncNormalizer;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMnc extends Model
{
    protected $table = 'network_mncs';

    protected $fillable = [
        'network_id',
        'mcc',
        'mnc',
        'mcc_mnc',
        'marked_for_deletion',
        'created_by_user_id',
        'updated_by_user_id',
        'created_by_source',
        'updated_by_source',
    ];

    protected $casts = [
        'marked_for_deletion' => 'bool',
    ];

    /**
     * Always recompute mcc, mnc, and mcc_mnc on save using MccMncNormalizer.
     *
     * This covers:
     * - Manual add/edit in the Networks UI.
     * - Any import job that persists NetworkMnc rows through Eloquent.
     *
     * Rule:
     *  - Build a 6-digit raw MCCMNC from MCC(3) + MNC(3) (padded).
     *  - Normalize via MccMncNormalizer (which trims the 4th digit 0 => 5-digit code).
     *  - Re-split normalized value into MCC (first 3) and MNC (last 2 or 3).
     *  - Persist all three: mcc, mnc, mcc_mnc.
     *
     * NOTE: There is also a DB trigger (normalize_network_mncs) on the network_mncs table
     * that enforces the same rule at the database level for raw inserts.
     */
    protected static function booted(): void
    {
        static::saving(function (NetworkMnc $model): void {
            if ($model->mcc === null || $model->mnc === null) {
                return;
            }

            // Sanitise into digits
            $mccDigits = preg_replace('/\D/', '', (string) $model->mcc);
            $mncDigits = preg_replace('/\D/', '', (string) $model->mnc);

            if ($mccDigits === '' || $mncDigits === '') {
                return;
            }

            // Build raw 6-digit MCCMNC from padded parts (3+3)
            $raw = str_pad($mccDigits, 3, '0', STR_PAD_LEFT)
                 . str_pad($mncDigits, 3, '0', STR_PAD_LEFT);

            $normalized = $raw;

            if (class_exists(MccMncNormalizer::class)) {
                $normalized = MccMncNormalizer::normalize($raw);
            } else {
                $normalized = preg_replace('/\D/', '', $raw);
            }

            $normalized = (string) $normalized;
            $len = strlen($normalized);

            if ($len < 5) {
                // Fallback: keep original ints, but at least store something in mcc_mnc
                $model->mcc_mnc = $normalized !== '' ? $normalized : $raw;
                return;
            }

            // MCC is always the first 3 digits
            $mccNorm = substr($normalized, 0, 3);

            // For 5-digit: MCC(3) + MNC(2)
            // For 6-digit: MCC(3) + MNC(3)
            if ($len === 5) {
                $mncNorm = substr($normalized, 3, 2);
            } else {
                $mncNorm = substr($normalized, 3);
            }

            $model->mcc = (int) $mccNorm;
            $model->mnc = (int) $mncNorm;
            $model->mcc_mnc = $normalized;
        });
    }

    public function network(): BelongsTo
    {
        return $this->belongsTo(Network::class);
    }

    /**
     * Accessor for formatted MCCMNC.
     *
     * Prefer the normalized mcc_mnc column if present; otherwise rebuild from mcc/mnc.
     */
    public function getMccMncFormattedAttribute(): string
    {
        if (!empty($this->mcc_mnc)) {
            return (string) $this->mcc_mnc;
        }

        $mcc = str_pad((string) $this->mcc, 3, '0', STR_PAD_LEFT);

        $mncStr = (string) $this->mnc;
        if ($mncStr === '') {
            return $mcc;
        }

        // If 1–2 digits, show as 2-digit; if 3+, show as-is
        $len = strlen($mncStr);
        if ($len <= 2) {
            $mnc = str_pad($mncStr, 2, '0', STR_PAD_LEFT);
        } else {
            $mnc = $mncStr;
        }

        return $mcc . $mnc;
    }
}
PHP

echo "==> Rewriting networks index view (MNC chips + filters + sort)" | tee -a "$LOG_FILE"

cat > "$NET_INDEX" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Networks
        </h2>
    </x-slot>

    @php
        $request        = request();

        $q              = trim((string) $request->input('q', ''));
        $countryId      = $request->input('country_id');
        $countryLabel   = trim((string) $request->input('country_label', ''));
        $nonOperational = $request->input('non_operational'); // '', '1', '0'
        $sort           = $request->input('sort', 'country');
        $direction      = strtolower((string) $request->input('direction', 'asc')) === 'desc' ? 'desc' : 'asc';
        $perPage        = (int) $request->input('per_page', 25);

        if ($perPage <= 0 || $perPage > 200) {
            $perPage = 25;
        }

        // Countries for typeahead dropdown
        $countries = \App\Models\Country::orderBy('name')->get();

        if ($countryLabel === '' && $countryId) {
            $c = $countries->firstWhere('id', (int) $countryId);
            if ($c) {
                $countryLabel = trim($c->name . ' (' . $c->iso2 . ')');
            }
        }

        $query = \App\Models\Network::query()
            ->with(['mncs', 'country'])
            ->leftJoin('countries as c', 'networks.country_id', '=', 'c.id')
            ->leftJoin('network_meta as nm', 'nm.network_id', '=', 'networks.id')
            ->select(
                'networks.*',
                'c.name as country_name',
                'c.iso2 as country_iso2',
                'nm.non_operational',
                'nm.notes as meta_notes'
            );

        if ($q !== '') {
            $query->whereRaw('LOWER(networks.name) LIKE ?', ['%' . strtolower($q) . '%']);
        }

        if ($countryId) {
            $query->where('networks.country_id', $countryId);
        }

        if ($nonOperational === '1') {
            $query->where('nm.non_operational', true);
        } elseif ($nonOperational === '0') {
            $query->where(function ($q2) {
                $q2->where('nm.non_operational', false)
                   ->orWhereNull('nm.non_operational');
            });
        }

        if ($sort === 'name') {
            $query->orderBy('networks.name', $direction)
                  ->orderBy('country_name', 'asc');
        } else {
            $query->orderBy('country_name', $direction)
                  ->orderBy('networks.name', 'asc');
            $sort = 'country';
        }

        $networks = $query->paginate($perPage)->appends($request->query());

        $countryNextDir = ($sort === 'country' && $direction === 'asc') ? 'desc' : 'asc';
        $nameNextDir    = ($sort === 'name' && $direction === 'asc') ? 'desc' : 'asc';
    @endphp

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
        @includeIf('partials.flash_log')

        {{-- Filters – single row: q, country typeahead, non-operational --}}
        <div class="bg-white shadow-sm sm:rounded-lg p-4 space-y-4">
            <form method="GET" action="{{ route('networks.index') }}" id="networks-filter-form">
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4 items-end">
                    {{-- Search by name (q) --}}
                    <div class="md:col-span-2">
                        <label for="filter_q" class="block text-sm font-medium text-gray-700">
                            Search name
                        </label>
                        <input
                            type="text"
                            id="filter_q"
                            name="q"
                            value="{{ $q }}"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            placeholder="e.g. Cosmote"
                        >
                    </div>

                    {{-- Country filter with typeahead + keyboard navigation --}}
                    <div class="relative">
                        <label for="filter_country_name" class="block text-sm font-medium text-gray-700">
                            Country
                        </label>

                        <input type="hidden" name="country_id" id="filter_country_id" value="{{ $countryId }}">

                        <input
                            type="text"
                            id="filter_country_name"
                            name="country_label"
                            autocomplete="off"
                            value="{{ $countryLabel }}"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            placeholder="Start typing country name..."
                        >

                        <ul
                            id="country_suggestions"
                            class="absolute z-20 mt-1 w-full bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto text-sm hidden"
                        >
                            @foreach ($countries as $country)
                                @php
                                    $label = trim($country->name . ' (' . $country->iso2 . ')');
                                @endphp
                                <li
                                    class="px-3 py-1 cursor-pointer hover:bg-indigo-50"
                                    data-id="{{ $country->id }}"
                                    data-label="{{ $label }}"
                                >
                                    {{ $label }}
                                </li>
                            @endforeach
                        </ul>
                    </div>

                    {{-- Non-operational filter --}}
                    <div>
                        <label for="filter_non_operational" class="block text-sm font-medium text-gray-700">
                            Non-operational
                        </label>
                        <select
                            id="filter_non_operational"
                            name="non_operational"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        >
                            <option value="">All</option>
                            <option value="1" @selected($nonOperational === '1')>Only non-operational</option>
                            <option value="0" @selected($nonOperational === '0')>Only operational</option>
                        </select>
                    </div>
                </div>

                <div class="mt-4 flex flex-wrap items-center justify-between gap-2">
                    <div class="flex flex-wrap items-center gap-2">
                        <button
                            type="submit"
                            class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-xs font-semibold text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                        >
                            Apply filters
                        </button>
                        <a
                            href="{{ route('networks.index') }}"
                            class="inline-flex items-center rounded-md border border-gray-300 bg-white px-3 py-2 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50"
                        >
                            Reset
                        </a>
                    </div>

                    <div class="flex items-center gap-2 text-xs text-gray-500">
                        <span>Sort:</span>
                        <a
                            href="{{ route('networks.index', array_merge(request()->except('page'), ['sort' => 'country', 'direction' => $countryNextDir])) }}"
                            class="inline-flex items-center gap-1 rounded px-2 py-1 border {{ $sort === 'country' ? 'border-indigo-500 text-indigo-700 bg-indigo-50' : 'border-gray-300 text-gray-700 bg-white' }}"
                        >
                            Country
                            @if ($sort === 'country')
                                <span class="text-[10px]">
                                    {{ $direction === 'asc' ? '▲' : '▼' }}
                                </span>
                            @endif
                        </a>
                        <a
                            href="{{ route('networks.index', array_merge(request()->except('page'), ['sort' => 'name', 'direction' => $nameNextDir])) }}"
                            class="inline-flex items-center gap-1 rounded px-2 py-1 border {{ $sort === 'name' ? 'border-indigo-500 text-indigo-700 bg-indigo-50' : 'border-gray-300 text-gray-700 bg-white' }}"
                        >
                            Name
                            @if ($sort === 'name')
                                <span class="text-[10px]">
                                    {{ $direction === 'asc' ? '▲' : '▼' }}
                                </span>
                            @endif
                        </a>
                    </div>
                </div>

                <input type="hidden" name="sort" id="networks_sort" value="{{ $sort }}">
                <input type="hidden" name="direction" id="networks_direction" value="{{ $direction }}">
                <input type="hidden" name="per_page" id="networks_per_page" value="{{ $perPage }}">
            </form>
        </div>

        {{-- Results table --}}
        <div class="overflow-x-auto rounded-lg border bg-white">
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                        <th class="px-4 py-3">
                            <a href="{{ route('networks.index', array_merge(request()->except('page'), ['sort' => 'country', 'direction' => $countryNextDir])) }}"
                               class="inline-flex items-center gap-1">
                                Country
                                @if ($sort === 'country')
                                    <span class="text-[10px] text-gray-500">
                                        {{ $direction === 'asc' ? '▲' : '▼' }}
                                    </span>
                                @endif
                            </a>
                        </th>
                        <th class="px-4 py-3">
                            <a href="{{ route('networks.index', array_merge(request()->except('page'), ['sort' => 'name', 'direction' => $nameNextDir])) }}"
                               class="inline-flex items-center gap-1">
                                Name
                                @if ($sort === 'name')
                                    <span class="text-[10px] text-gray-500">
                                        {{ $direction === 'asc' ? '▲' : '▼' }}
                                    </span>
                                @endif
                            </a>
                        </th>
                        <th class="px-4 py-3">MNCs</th>
                        <th class="px-4 py-3">Non-operational</th>
                        <th class="px-4 py-3">Notes</th>
                        <th class="px-4 py-3 text-right">Actions</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 text-sm">
                    @forelse ($networks as $network)
                        <tr>
                            <td class="px-4 py-2 whitespace-nowrap">
                                @if ($network->country_name)
                                    <span class="font-medium text-gray-900">
                                        {{ $network->country_name }}
                                    </span>
                                    <span class="ml-1 text-xs text-gray-500">
                                        ({{ $network->country_iso2 }})
                                    </span>
                                @else
                                    <span class="text-xs text-gray-400">—</span>
                                @endif
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap">
                                <span class="text-gray-900 font-medium">
                                    {{ $network->name }}
                                </span>
                            </td>
                            <td class="px-4 py-2">
                                <div class="flex flex-wrap gap-1">
                                    @forelse ($network->mncs as $mnc)
                                        @php
                                            $mncStr = (string) $mnc->mnc;
                                            $len = strlen($mncStr);
                                            if ($len <= 2) {
                                                $mncDisplay = str_pad($mncStr, 2, '0', STR_PAD_LEFT);
                                            } else {
                                                $mncDisplay = $mncStr;
                                            }
                                        @endphp
                                        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-indigo-50 text-indigo-700">
                                            {{ $mncDisplay }}
                                        </span>
                                    @empty
                                        <span class="text-xs text-gray-400">—</span>
                                    @endforelse
                                </div>
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap">
                                @if ($network->non_operational)
                                    <span class="inline-flex items-center rounded-full bg-red-50 px-2 py-0.5 text-xs font-medium text-red-700">
                                        Non-operational
                                    </span>
                                @else
                                    <span class="inline-flex items-center rounded-full bg-green-50 px-2 py-0.5 text-xs font-medium text-green-700">
                                        Operational
                                    </span>
                                @endif
                            </td>
                            <td class="px-4 py-2">
                                @if ($network->meta_notes)
                                    <span class="block text-xs text-gray-700">
                                        {{ \Illuminate\Support\Str::limit($network->meta_notes, 80) }}
                                    </span>
                                @else
                                    <span class="text-xs text-gray-400">—</span>
                                @endif
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-right text-xs">
                                <a
                                    href="{{ route('networks.edit', $network->id) }}"
                                    class="inline-flex items-center rounded-md border border-gray-300 bg-white px-2.5 py-1 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50"
                                >
                                    Edit
                                </a>
                                <form
                                    action="{{ route('networks.destroy', $network->id) }}"
                                    method="POST"
                                    class="inline-block ml-1"
                                    onsubmit="return confirm('Are you sure you want to delete this network?');"
                                >
                                    @csrf
                                    @method('DELETE')
                                    <button
                                        type="submit"
                                        class="inline-flex items-center rounded-md border border-red-300 bg-white px-2.5 py-1 text-xs font-medium text-red-700 shadow-sm hover:bg-red-50"
                                    >
                                        Delete
                                    </button>
                                </form>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="px-4 py-6 text-center text-sm text-gray-500">
                                No networks found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        {{-- Pagination + per-page selector at bottom --}}
        <div class="mt-4 flex flex-col md:flex-row items-center justify-between gap-3 text-sm text-gray-600">
            <div>
                @if ($networks->total() > 0)
                    Showing
                    <span class="font-semibold">{{ $networks->firstItem() }}</span>
                    –
                    <span class="font-semibold">{{ $networks->lastItem() }}</span>
                    of
                    <span class="font-semibold">{{ $networks->total() }}</span>
                    networks
                @else
                    No results
                @endif
            </div>
            <div class="flex items-center gap-4">
                <form method="GET" action="{{ route('networks.index') }}" class="flex items-center gap-2">
                    @foreach(request()->except('per_page', 'page') as $key => $value)
                        <input type="hidden" name="{{ $key }}" value="{{ $value }}">
                    @endforeach
                    <label for="per_page" class="text-xs text-gray-500">
                        Rows per page
                    </label>
                    <select
                        id="per_page"
                        name="per_page"
                        class="rounded-md border-gray-300 text-xs shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        onchange="this.form.submit()"
                    >
                        @foreach ([10, 25, 50, 100, 200] as $size)
                            <option value="{{ $size }}" @selected($perPage === $size)>{{ $size }}</option>
                        @endforeach
                    </select>
                </form>

                <div>
                    {{ $networks->links() }}
                </div>
            </div>
        </div>
    </div>

    {{-- Country typeahead + keyboard navigation --}}
    <script>
        (function () {
            var input      = document.getElementById('filter_country_name');
            var hiddenId   = document.getElementById('filter_country_id');
            var list       = document.getElementById('country_suggestions');

            if (!input || !hiddenId || !list) return;

            var items = Array.prototype.slice.call(list.querySelectorAll('li'));
            var currentIndex = -1;

            function openList() {
                list.classList.remove('hidden');
            }

            function closeList() {
                list.classList.add('hidden');
                currentIndex = -1;
                updateHighlight();
            }

            function updateHighlight() {
                items.forEach(function (li, idx) {
                    li.classList.remove('bg-indigo-600', 'text-white');
                    if (idx === currentIndex) {
                        li.classList.add('bg-indigo-600', 'text-white');
                    }
                });
            }

            function visibleItems() {
                return items.filter(function (li) {
                    return li.style.display !== 'none';
                });
            }

            function selectItem(li) {
                var id    = li.getAttribute('data-id');
                var label = li.getAttribute('data-label') || li.textContent;
                hiddenId.value = id || '';
                input.value    = (label || '').trim();
                closeList();
            }

            input.addEventListener('input', function () {
                var term = (this.value || '').toLowerCase();
                var anyVisible = false;

                items.forEach(function (li) {
                    var label = (li.getAttribute('data-label') || li.textContent || '').toLowerCase();
                    var match = !term || label.indexOf(term) !== -1;
                    li.style.display = match ? '' : 'none';
                    if (match) anyVisible = true;
                });

                if (anyVisible) {
                    openList();
                } else {
                    closeList();
                }
            });

            input.addEventListener('keydown', function (e) {
                var vis = visibleItems();
                if (!vis.length) return;

                if (e.key === 'ArrowDown') {
                    e.preventDefault();
                    if (currentIndex < vis.length - 1) {
                        currentIndex++;
                    } else {
                        currentIndex = 0;
                    }
                    var li = vis[currentIndex];
                    currentIndex = items.indexOf(li);
                    updateHighlight();
                } else if (e.key === 'ArrowUp') {
                    e.preventDefault();
                    if (currentIndex > 0) {
                        currentIndex--;
                    } else {
                        currentIndex = vis.length - 1;
                    }
                    var liUp = vis[currentIndex];
                    currentIndex = items.indexOf(liUp);
                    updateHighlight();
                } else if (e.key === 'Enter') {
                    if (currentIndex >= 0) {
                        e.preventDefault();
                        var liEnter = items[currentIndex];
                        selectItem(liEnter);
                    }
                } else if (e.key === 'Escape') {
                    closeList();
                }
            });

            items.forEach(function (li) {
                li.addEventListener('mousedown', function (e) {
                    e.preventDefault();
                    selectItem(li);
                });
            });

            document.addEventListener('click', function (e) {
                if (e.target === input || list.contains(e.target)) return;
                closeList();
            });
        })();
    </script>
</x-app-layout>
BLADE

# === DB migration for Postgres trigger on network_mncs ===

MIG_DIR="$ROOT_DIR/database/migrations"
existing_mig="$(ls "$MIG_DIR"/*_add_network_mncs_normalizer_trigger.php 2>/dev/null | head -n 1 || true)"

if [ -n "$existing_mig" ]; then
  MIG_FILE="$existing_mig"
  echo "==> Reusing existing migration file: $MIG_FILE" | tee -a "$LOG_FILE"
  backup_file "$MIG_FILE"
else
  MIG_TS="$(date +%Y_%m_%d_%H%M%S)"
  MIG_FILE="$MIG_DIR/${MIG_TS}_add_network_mncs_normalizer_trigger.php"
  echo "==> Creating new migration file: $MIG_FILE" | tee -a "$LOG_FILE"
  register_new_file "$MIG_FILE"
fi

cat > "$MIG_FILE" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Create or replace function that normalizes MCC/MNC:
        // - Build raw MCCMNC from padded MCC(3) + MNC(3)
        // - If 6 digits and 4th digit is '0', drop that '0' => 5-digit code
        // - Recompute MCC (first 3) and MNC (last 2 or 3) from normalized value
        DB::unprepared(<<<'SQL'
CREATE OR REPLACE FUNCTION normalize_network_mncs()
RETURNS trigger AS $$
DECLARE
    v_mcc   text;
    v_mnc   text;
    v_raw   text;
    v_norm  text;
    v_len   int;
BEGIN
    IF NEW.mcc IS NULL OR NEW.mnc IS NULL THEN
        RETURN NEW;
    END IF;

    -- Strip to digits
    v_mcc := regexp_replace(COALESCE(NEW.mcc::text, ''), '\D', '', 'g');
    v_mnc := regexp_replace(COALESCE(NEW.mnc::text, ''), '\D', '', 'g');

    IF v_mcc = '' OR v_mnc = '' THEN
        RETURN NEW;
    END IF;

    -- Build raw MCCMNC as 6 digits: MCC(3) + MNC(3)
    v_raw := lpad(v_mcc, 3, '0') || lpad(v_mnc, 3, '0');

    -- Keep only digits, max 6 chars
    v_norm := regexp_replace(v_raw, '\D', '', 'g');
    v_len  := length(v_norm);

    IF v_len > 6 THEN
        v_norm := substring(v_norm from 1 for 6);
        v_len  := 6;
    END IF;

    -- If 6 digits and 4th digit is '0', drop that '0' => 5-digit composite
    IF v_len = 6 AND substring(v_norm from 4 for 1) = '0' THEN
        v_norm := substring(v_norm from 1 for 3) || substring(v_norm from 5);
        v_len  := 5;
    END IF;

    -- If we ended up with fewer than 5 digits, just store what we have in mcc_mnc
    IF v_len < 5 THEN
        NEW.mcc_mnc := v_norm;
        RETURN NEW;
    END IF;

    -- MCC is always first 3
    NEW.mcc := substring(v_norm from 1 for 3)::integer;

    -- For 5-digit: MCC(3) + MNC(2)
    -- For 6-digit: MCC(3) + MNC(3)
    IF v_len = 5 THEN
        NEW.mnc := substring(v_norm from 4 for 2)::integer;
    ELSE
        NEW.mnc := substring(v_norm from 4)::integer;
    END IF;

    NEW.mcc_mnc := v_norm;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_network_mncs_normalize ON network_mncs;

CREATE TRIGGER trg_network_mncs_normalize
BEFORE INSERT OR UPDATE ON network_mncs
FOR EACH ROW EXECUTE FUNCTION normalize_network_mncs();
SQL
        );

        // Retro-normalize all existing rows by forcing an UPDATE
        DB::unprepared("UPDATE network_mncs SET mcc = mcc WHERE mcc IS NOT NULL AND mnc IS NOT NULL;");
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
DROP TRIGGER IF EXISTS trg_network_mncs_normalize ON network_mncs;
DROP FUNCTION IF EXISTS normalize_network_mncs();
SQL
        );
    }
};
PHP

echo "==> Migration file ready: $MIG_FILE" | tee -a "$LOG_FILE"

# Run migrations
echo "==> Running php artisan migrate --force" | tee -a "$LOG_FILE"
detect_artisan_service
run_artisan "php artisan migrate --force"

# Clear & rebuild caches
echo "==> Clearing & rebuilding caches (optimize:clear, view:cache)" | tee -a "$LOG_FILE"
run_artisan "php artisan optimize:clear" || true
run_artisan "php artisan view:cache" || true

trap - ERR

echo "==> mnc_full_pipeline_v1.sh completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE"                | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
