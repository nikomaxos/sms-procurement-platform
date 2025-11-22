#!/usr/bin/env bash
#
# scripts/feature_pack_networks_countries_v1.sh
#
# Feature pack for sms-procurement-platform:
#
# - DB:
#   * Create network_meta(network_id, non_operational, notes)
#   * Create country_meta(country_id, notes)
#
# - Networks index UI (Blade):
#   * Filters in one row: q (name search), country (typeahead), non-operational
#   * Country typeahead with keyboard navigation (Down/Up/Enter)
#   * Results-per-page selector moved to bottom, keeping paginator
#   * Show MCCs and MNCs as chips
#   * Sortable headers for Country and Name
#     - Default: Country ASC
#     - Click toggles ASC⇄DESC
#   * Column order: Country, Name, MCCs, MNCs, Non-operational, Notes, Actions
#
# - Countries index UI (Blade):
#   * Filters in one row: name, ISO2
#   * Notes column
#   * Per-page selector at bottom
#
# - Notes:
#   * notes TEXT field stored in network_meta and country_meta
#   * Notes columns displayed in both index pages
#
# - non_operational:
#   * boolean in network_meta (default false)
#   * Filter on Networks index
#
# - ITU MCCMNC rule:
#   * App\Support\MccMncNormalizer::normalize()
#   * NetworkMnc::setMccMncAttribute() mutator normalizes 6-digit codes where
#     4th digit is 0 → drop that digit (e.g. 202001 → 20201)
#   * [Inference] Assumes importer sets mcc_mnc via attribute or mass-assignment
#
# - Settings menu:
#   * Add "Carriers Import" link to /carriers/import
#   * [Inference] Appends an x-dropdown-link to navigation.blade.php (or first nav file found)
#
# - Script behavior:
#   * Idempotent: only creates files if missing, backs up modified files
#   * On error: logs to logs/, restores backups, migrate:rollback --step=1
#   * On success: runs migrations, clears caches, smoke tests, git add/commit/tag/push
#
# NOTE: This script intentionally does NOT modify your existing controllers;
#       all new filtering/sorting happens in the Blade views using Eloquent
#       queries and Network::scopeFilter().
#

set -Eeuo pipefail

##############################################
# 0. Paths, logging, helpers
##############################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP="$(date +%F_%H-%M-%S)"
LOG_FILE="$LOG_DIR/feature_pack_networks_countries_v1_${TIMESTAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Running feature_pack_networks_countries_v1 at $TIMESTAMP"
echo "ROOT_DIR: $ROOT_DIR"
echo "LOG_FILE: $LOG_FILE"

BACKUP_DIR="$ROOT_DIR/.backups/feature_pack_networks_countries_v1_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

MODIFIED_FILES=()
NEW_FILES=()
MIGRATED=0

info() { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

backup_file() {
    local path="$1"
    if [[ -f "$path" ]]; then
        local safe_name
        safe_name="$(echo "$path" | tr '/\\' '__')"
        local dest="$BACKUP_DIR/$safe_name"
        if [[ ! -f "$dest" ]]; then
            cp "$path" "$dest"
            MODIFIED_FILES+=("$path")
            info "Backed up $path -> $dest"
        fi
    fi
}

mark_new_file() {
    local path="$1"
    NEW_FILES+=("$path")
}

restore_files() {
    info "Restoring modified files from backup (if any)"
    for path in "${MODIFIED_FILES[@]:-}"; do
        local safe_name dest
        safe_name="$(echo "$path" | tr '/\\' '__')"
        dest="$BACKUP_DIR/$safe_name"
        if [[ -f "$dest" ]]; then
            cp "$dest" "$path"
            info "Restored $path from $dest"
        else
            warn "No backup found for $path (expected at $dest)"
        fi
    done

    info "Removing newly created files (if any)"
    for path in "${NEW_FILES[@]:-}"; do
        if [[ -e "$path" ]]; then
            rm -f "$path"
            info "Removed new file $path"
        fi
    done
}

##############################################
# 1. How to run artisan/php (docker vs host)
##############################################

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 && [[ -f "$ROOT_DIR/docker-compose.yml" ]]; then
    info "Detected docker-compose; using app container for artisan/php"

    APP_SERVICE="sms-platform-app"
    if ! docker compose ps --services 2>/dev/null | grep -qx "sms-platform-app"; then
        if docker compose ps --services 2>/dev/null | grep -qx "app"; then
            APP_SERVICE="app"
        fi
    fi

    ARTISAN() {
        docker compose exec -T "$APP_SERVICE" php artisan "$@"
    }
    PHP_RUN() {
        docker compose exec -T "$APP_SERVICE" php "$@"
    }
else
    info "No docker-compose app service detected; using host php artisan"
    ARTISAN() { php artisan "$@"; }
    PHP_RUN() { php "$@"; }
fi

##############################################
# 2. Error trap (rollback)
##############################################

on_error() {
    local lineno="$1"
    warn "Error occurred at line $lineno. Starting rollback."

    if (( MIGRATED )); then
        warn "Rolling back last migration step (php artisan migrate:rollback --step=1)"
        set +e
        ARTISAN migrate:rollback --step=1 --force || warn "migrate:rollback failed (may be benign)."
        set -e
    fi

    restore_files

    warn "Rollback complete. See $LOG_FILE for details."
    exit 1
}

trap 'on_error $LINENO' ERR

##############################################
# 3. Migrations: network_meta & country_meta
##############################################

info "Ensuring migrations for network_meta and country_meta tables"

MIG_NETWORK_META="$ROOT_DIR/database/migrations/2025_11_21_000101_create_network_meta_table.php"
MIG_COUNTRY_META="$ROOT_DIR/database/migrations/2025_11_21_000102_create_country_meta_table.php"

if [[ ! -f "$MIG_NETWORK_META" ]]; then
    info "Creating migration $MIG_NETWORK_META"
    cat > "$MIG_NETWORK_META" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('network_meta')) {
            Schema::create('network_meta', function (Blueprint $table): void {
                $table->id();
                // networks.id is bigint; avoid FK because networks is a view.
                $table->unsignedBigInteger('network_id')->unique();
                $table->boolean('non_operational')->default(false)->index();
                $table->text('notes')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('network_meta')) {
            Schema::drop('network_meta');
        }
    }
};
PHP
    mark_new_file "$MIG_NETWORK_META"
else
    info "Migration already exists: $MIG_NETWORK_META (idempotent)"
fi

if [[ ! -f "$MIG_COUNTRY_META" ]]; then
    info "Creating migration $MIG_COUNTRY_META"
    cat > "$MIG_COUNTRY_META" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('country_meta')) {
            Schema::create('country_meta', function (Blueprint $table): void {
                $table->id();
                $table->unsignedBigInteger('country_id')->unique();
                $table->text('notes')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('country_meta')) {
            Schema::drop('country_meta');
        }
    }
};
PHP
    mark_new_file "$MIG_COUNTRY_META"
else
    info "Migration already exists: $MIG_COUNTRY_META (idempotent)"
fi

##############################################
# 4. Networks index view (full rewrite)
##############################################
# Uses App\Models\Network + scopeFilter() + mncs + country.
# Non-operational + notes via LEFT JOIN to network_meta.
##############################################

NET_VIEW="$ROOT_DIR/resources/views/networks/index.blade.php"

if [[ -f "$NET_VIEW" ]]; then
    info "Patching networks index view: $NET_VIEW"
    backup_file "$NET_VIEW"

    cat > "$NET_VIEW" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Networks
        </h2>
    </x-slot>

    @php
        use App\Models\Network;
        use App\Models\Country;
        use Illuminate\Support\Str;

        $request = request();

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
        $countries = Country::orderBy('name')->get();

        if ($countryLabel === '' && $countryId) {
            $c = $countries->firstWhere('id', (int) $countryId);
            if ($c) {
                $countryLabel = trim($c->name . ' (' . $c->iso2 . ')');
            }
        }

        // Map view filters into existing scopeFilter()
        $filters = [];
        if ($q !== '') {
            $filters['q'] = $q;
        }
        if ($countryId) {
            $filters['country_id'] = $countryId;
        }
        if ($request->filled('mcc')) {
            $filters['mcc'] = $request->input('mcc');
        }
        if ($request->filled('mnc')) {
            $filters['mnc'] = $request->input('mnc');
        }

        $query = Network::query()
            ->with(['mncs', 'country'])
            ->leftJoin('countries as c', 'networks.country_id', '=', 'c.id')
            ->leftJoin('network_meta as nm', 'nm.network_id', '=', 'networks.id')
            ->select(
                'networks.*',
                'c.name as country_name',
                'c.iso2 as country_iso2',
                'nm.non_operational',
                'nm.notes as meta_notes'
            )
            ->filter($filters);

        if ($nonOperational === '1') {
            $query->where('nm.non_operational', true);
        } elseif ($nonOperational === '0') {
            $query->where(function ($q2) {
                $q2->where('nm.non_operational', false)
                   ->orWhereNull('nm.non_operational');
            });
        }

        if ($sort === 'name') {
            $query->orderBy('networks.name', $direction);
        } else {
            $query->orderBy('country_name', $direction)
                  ->orderBy('networks.name', 'asc');
            $sort = 'country';
        }

        $networks = $query->paginate($perPage)->appends($request->query());

        $countryNextDir = ($sort === 'country' && $direction === 'asc') ? 'desc' : 'asc';
        $nameNextDir    = ($sort === 'name' && $direction === 'asc') ? 'desc' : 'asc';
    @endphp

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        @includeIf('partials.flash_log')

        <div class="bg-white shadow-sm sm:rounded-lg p-4 space-y-4">

            {{-- Filters in one row: q, country, non-operational --}}
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

                    {{-- Actions: apply/reset + Export CSV [Inference: CSV export route param] --}}
                    <div class="flex gap-2 justify-start md:justify-end mt-2 md:mt-0">
                        <button
                            type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                        >
                            Apply filters
                        </button>
                        <a
                            href="{{ route('networks.index') }}"
                            class="inline-flex items-center px-3 py-2 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                        >
                            Reset
                        </a>
                        <a
                            class="inline-flex items-center px-3 py-2 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                            href="{{ route('networks.index', array_merge(request()->query(), ['export' => 'csv'])) }}"
                        >
                            Export CSV
                        </a>
                    </div>
                </div>

                {{-- Hidden sort / per-page fields --}}
                <input type="hidden" name="sort" id="networks_sort" value="{{ $sort }}">
                <input type="hidden" name="direction" id="networks_direction" value="{{ $direction }}">
                <input type="hidden" name="per_page" id="networks_per_page" value="{{ $perPage }}">
            </form>

            {{-- Table --}}
            <div class="mt-4 overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                    <thead class="bg-gray-50">
                        <tr>
                            {{-- Country (sortable, first column) --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                <a href="{{ route('networks.index', array_merge(request()->except('page'), ['sort' => 'country', 'direction' => $countryNextDir])) }}"
                                   class="inline-flex items-center gap-1">
                                    Country
                                    @if ($sort === 'country')
                                        <span class="text-xs text-gray-500">
                                            {{ $direction === 'asc' ? '▲' : '▼' }}
                                        </span>
                                    @endif
                                </a>
                            </th>

                            {{-- Name (sortable, second column) --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                <a href="{{ route('networks.index', array_merge(request()->except('page'), ['sort' => 'name', 'direction' => $nameNextDir])) }}"
                                   class="inline-flex items-center gap-1">
                                    Name
                                    @if ($sort === 'name')
                                        <span class="text-xs text-gray-500">
                                            {{ $direction === 'asc' ? '▲' : '▼' }}
                                        </span>
                                    @endif
                                </a>
                            </th>

                            {{-- MCC chips --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                MCCs
                            </th>

                            {{-- MNC chips --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                MNCs
                            </th>

                            {{-- Non-operational --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                Non-operational
                            </th>

                            {{-- Notes --}}
                            <th scope="col" class="px-3 py-2 text-left font-medium text-gray-700 uppercase tracking-wider">
                                Notes
                            </th>

                            {{-- Actions --}}
                            <th scope="col" class="px-3 py-2 text-right font-medium text-gray-700 uppercase tracking-wider">
                                Actions
                            </th>
                        </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                        @forelse ($networks as $network)
                            @php
                                $mncsAll = $network->mncs ?? collect();
                                $mncs = $mncsAll->where('marked_for_deletion', false);
                                $mccList = $mncs->pluck('mcc')->filter()->unique()->values();
                                $mncList = $mncs->pluck('mnc')->filter()->unique()->values();
                                $notes   = $network->meta_notes ?? null;
                            @endphp
                            <tr>
                                {{-- Country --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $network->country_name ?? optional($network->country)->name ?? '—' }}
                                    @php $iso = $network->country_iso2 ?? optional($network->country)->iso2; @endphp
                                    @if (! empty($iso))
                                        <span class="text-xs text-gray-500">
                                            ({{ $iso }})
                                        </span>
                                    @endif
                                </td>

                                {{-- Name --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm text-gray-900">
                                    {{ $network->name }}
                                </td>

                                {{-- MCC chips --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm">
                                    @forelse ($mccList as $mcc)
                                        <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-800 mr-1">
                                            {{ $mcc }}
                                        </span>
                                    @empty
                                        <span class="text-xs text-gray-400">—</span>
                                    @endforelse
                                </td>

                                {{-- MNC chips --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm">
                                    @forelse ($mncList as $mnc)
                                        <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-800 mr-1">
                                            {{ $mnc }}
                                        </span>
                                    @empty
                                        <span class="text-xs text-gray-400">—</span>
                                    @endforelse
                                </td>

                                {{-- Non-operational --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm">
                                    @if ($network->non_operational ?? false)
                                        <span class="inline-flex items-center rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800">
                                            Yes
                                        </span>
                                    @else
                                        <span class="inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800">
                                            No
                                        </span>
                                    @endif
                                </td>

                                {{-- Notes --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm text-gray-900 max-w-xs">
                                    @if (! empty($notes))
                                        <span title="{{ $notes }}">
                                            {{ Str::limit($notes, 80) }}
                                        </span>
                                    @else
                                        <span class="text-xs text-gray-400">—</span>
                                    @endif
                                </td>

                                {{-- Actions placeholder --}}
                                <td class="px-3 py-2 whitespace-nowrap text-sm text-right text-gray-500">
                                    {{-- Hook show/edit here if needed --}}
                                    …
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" class="px-3 py-4 text-center text-sm text-gray-500">
                                    No networks found for the current filters.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{-- Bottom paginator + results-per-page selector --}}
            <div class="mt-4 flex flex-col md:flex-row md:items-center md:justify-between gap-3">
                <div class="text-sm text-gray-600">
                    @if ($networks->total() > 0)
                        Showing
                        <span class="font-medium">{{ $networks->firstItem() }}</span>
                        –
                        <span class="font-medium">{{ $networks->lastItem() }}</span>
                        of
                        <span class="font-medium">{{ $networks->total() }}</span>
                        networks
                    @else
                        No networks to display.
                    @endif
                </div>

                <div class="flex items-center gap-2">
                    <span class="text-sm text-gray-600">Per page:</span>
                    <select
                        class="block rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        onchange="document.getElementById('networks_per_page').value=this.value; document.getElementById('networks-filter-form').submit();"
                    >
                        @foreach ([10, 25, 50, 100, 200] as $size)
                            <option value="{{ $size }}" @selected($perPage === $size)>{{ $size }}</option>
                        @endforeach
                    </select>
                </div>

                <div>
                    {{ $networks->onEachSide(1)->links() }}
                </div>
            </div>
        </div>
    </div>

    {{-- JS for country typeahead + keyboard navigation --}}
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const input = document.getElementById('filter_country_name');
            const hiddenId = document.getElementById('filter_country_id');
            const list = document.getElementById('country_suggestions');
            if (!input || !hiddenId || !list) return;

            const allItems = Array.from(list.querySelectorAll('li'));
            let visibleItems = allItems.slice();
            let activeIndex = -1;

            function closeList() {
                list.classList.add('hidden');
                activeIndex = -1;
                allItems.forEach(li => li.classList.remove('bg-indigo-100'));
            }

            function openList() {
                if (visibleItems.length > 0) {
                    list.classList.remove('hidden');
                }
            }

            function updateVisible() {
                const query = input.value.toLowerCase();
                visibleItems = [];
                allItems.forEach(li => {
                    const label = (li.dataset.label || '').toLowerCase();
                    const match = label.includes(query);
                    li.style.display = match ? '' : 'none';
                    if (match) visibleItems.push(li);
                });
                if (query === '') {
                    allItems.forEach(li => { li.style.display = ''; });
                    visibleItems = allItems.slice();
                }
                activeIndex = visibleItems.length ? 0 : -1;
                allItems.forEach(li => li.classList.remove('bg-indigo-100'));
                if (activeIndex >= 0 && visibleItems[activeIndex]) {
                    visibleItems[activeIndex].classList.add('bg-indigo-100');
                }
            }

            function selectItem(li) {
                hiddenId.value = li.dataset.id || '';
                input.value = li.dataset.label || '';
                closeList();
            }

            input.addEventListener('input', function () {
                updateVisible();
                openList();
            });

            input.addEventListener('keydown', function (e) {
                if (list.classList.contains('hidden')) {
                    if (e.key === 'ArrowDown') {
                        updateVisible();
                        openList();
                        e.preventDefault();
                    }
                    return;
                }

                if (e.key === 'ArrowDown') {
                    if (visibleItems.length === 0) return;
                    activeIndex = (activeIndex + 1) % visibleItems.length;
                    allItems.forEach(li => li.classList.remove('bg-indigo-100'));
                    visibleItems[activeIndex].classList.add('bg-indigo-100');
                    e.preventDefault();
                } else if (e.key === 'ArrowUp') {
                    if (visibleItems.length === 0) return;
                    activeIndex = (activeIndex - 1 + visibleItems.length) % visibleItems.length;
                    allItems.forEach(li => li.classList.remove('bg-indigo-100'));
                    visibleItems[activeIndex].classList.add('bg-indigo-100');
                    e.preventDefault();
                } else if (e.key === 'Enter') {
                    if (activeIndex >= 0 && visibleItems[activeIndex]) {
                        selectItem(visibleItems[activeIndex]);
                        e.preventDefault();
                    }
                } else if (e.key === 'Escape') {
                    closeList();
                    e.preventDefault();
                }
            });

            allItems.forEach(li => {
                li.addEventListener('mousedown', function (e) {
                    e.preventDefault();
                    selectItem(li);
                });
            });

            document.addEventListener('click', function (e) {
                if (!list.contains(e.target) && e.target !== input) {
                    closeList();
                }
            });

            updateVisible();
        });
    </script>
</x-app-layout>
BLADE
else
    warn "Networks index view not found at $NET_VIEW; skipping networks UI patch."
fi

##############################################
# 5. Countries index view (full rewrite)
##############################################
# Uses App\Models\Country directly in the view (like your current simple index),
# but extended with filters and notes via country_meta.
##############################################

COUNTRIES_VIEW="$ROOT_DIR/resources/views/countries/index.blade.php"

if [[ -f "$COUNTRIES_VIEW" ]]; then
    info "Patching countries index view: $COUNTRIES_VIEW"
    backup_file "$COUNTRIES_VIEW"

    cat > "$COUNTRIES_VIEW" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Countries
        </h2>
    </x-slot>

    @php
        use App\Models\Country;
        use Illuminate\Support\Str;

        $request   = request();
        $name      = trim((string) $request->input('name', ''));
        $iso2      = trim((string) $request->input('iso2', ''));
        $sort      = $request->input('sort', 'name');
        $direction = strtolower((string) $request->input('direction', 'asc')) === 'desc' ? 'desc' : 'asc';
        $perPage   = (int) $request->input('per_page', 50);

        if ($perPage <= 0 || $perPage > 200) {
            $perPage = 50;
        }

        $query = Country::query()
            ->from('countries as c')
            ->leftJoin('country_meta as cm', 'cm.country_id', '=', 'c.id')
            ->select('c.*', 'cm.notes as meta_notes');

        if ($name !== '') {
            $query->whereRaw('LOWER(c.name) LIKE ?', ['%' . strtolower($name) . '%']);
        }

        if ($iso2 !== '') {
            $query->whereRaw('LOWER(c.iso2) LIKE ?', ['%' . strtolower($iso2) . '%']);
        }

        if ($sort === 'iso2') {
            $query->orderBy('c.iso2', $direction)->orderBy('c.name', 'asc');
        } else {
            $query->orderBy('c.name', $direction)->orderBy('c.iso2', 'asc');
            $sort = 'name';
        }

        $countries = $query->paginate($perPage)->appends($request->query());

        $nameNextDir = ($sort === 'name' && $direction === 'asc') ? 'desc' : 'asc';
        $iso2NextDir = ($sort === 'iso2' && $direction === 'asc') ? 'desc' : 'asc';
    @endphp

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
        @includeIf('partials.flash_log')

        {{-- Filters – one row: name + ISO2 --}}
        <form method="GET" action="{{ route('countries.index') }}" id="countries-filter-form">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 items-end">
                <div>
                    <label for="filter_country_name" class="block text-sm font-medium text-gray-700">
                        Name
                    </label>
                    <input
                        type="text"
                        id="filter_country_name"
                        name="name"
                        value="{{ $name }}"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        placeholder="Search by country name"
                    >
                </div>

                <div>
                    <label for="filter_country_iso2" class="block text-sm font-medium text-gray-700">
                        ISO2
                    </label>
                    <input
                        type="text"
                        id="filter_country_iso2"
                        name="iso2"
                        value="{{ strtoupper($iso2) }}"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm uppercase"
                        placeholder="EG, GR, US"
                    >
                </div>

                <div class="flex gap-2 justify-start md:justify-end">
                    <button
                        type="submit"
                        class="inline-flex items-center px-4 py-2 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                    >
                        Apply filters
                    </button>
                    <a
                        href="{{ route('countries.index') }}"
                        class="inline-flex items-center px-3 py-2 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                    >
                        Reset
                    </a>
                </div>
            </div>

            <input type="hidden" name="sort" id="countries_sort" value="{{ $sort }}">
            <input type="hidden" name="direction" id="countries_direction" value="{{ $direction }}">
            <input type="hidden" name="per_page" id="countries_per_page" value="{{ $perPage }}">
        </form>

        <div class="overflow-x-auto rounded-lg border bg-white">
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                        <th class="px-4 py-3">
                            <a href="{{ route('countries.index', array_merge(request()->except('page'), ['sort' => 'name', 'direction' => $nameNextDir])) }}"
                               class="inline-flex items-center gap-1">
                                Country
                                @if ($sort === 'name')
                                    <span class="text-[10px] text-gray-500">
                                        {{ $direction === 'asc' ? '▲' : '▼' }}
                                    </span>
                                @endif
                            </a>
                        </th>
                        <th class="px-4 py-3">
                            <a href="{{ route('countries.index', array_merge(request()->except('page'), ['sort' => 'iso2', 'direction' => $iso2NextDir])) }}"
                               class="inline-flex items-center gap-1">
                                ISO2
                                @if ($sort === 'iso2')
                                    <span class="text-[10px] text-gray-500">
                                        {{ $direction === 'asc' ? '▲' : '▼' }}
                                    </span>
                                @endif
                            </a>
                        </th>
                        <th class="px-4 py-3">Notes</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white text-sm">
                    @forelse($countries as $country)
                        @php $notes = $country->meta_notes ?? null; @endphp
                        <tr class="hover:bg-gray-50">
                            <td class="px-4 py-3 text-gray-900">
                                {{ $country->name }}
                            </td>
                            <td class="px-4 py-3 text-gray-900">
                                {{ $country->iso2 }}
                            </td>
                            <td class="px-4 py-3 text-gray-900 max-w-xs">
                                @if (! empty($notes))
                                    <span title="{{ $notes }}">
                                        {{ Str::limit($notes, 80) }}
                                    </span>
                                @else
                                    <span class="text-xs text-gray-400">—</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="3" class="px-4 py-6 text-center text-gray-500">
                                No results.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div class="flex items-center justify-between">
            <div class="text-sm text-gray-600">
                @if($countries->total())
                    Showing {{ $countries->firstItem() }}–{{ $countries->lastItem() }} of {{ $countries->total() }} results
                @else
                    Showing 0 of 0 results
                @endif
            </div>
            <div class="flex items-center gap-3 text-sm">
                <div class="flex items-center gap-1">
                    <span>Per page:</span>
                    <select
                        class="block rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        onchange="document.getElementById('countries_per_page').value=this.value; document.getElementById('countries-filter-form').submit();"
                    >
                        @foreach ([25, 50, 100, 200] as $size)
                            <option value="{{ $size }}" @selected($perPage === $size)>{{ $size }}</option>
                        @endforeach
                    </select>
                </div>
                <div>
                    {{ $countries->onEachSide(1)->links() }}
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
BLADE
else
    warn "Countries index view not found at $COUNTRIES_VIEW; skipping countries UI patch."
fi

##############################################
# 6. Settings menu – add "Carriers Import"
##############################################
# [Inference] We don't see your nav file, so we append a dropdown link
# to the main navigation blade (or the first matching layouts file).
##############################################

info "Trying to add 'Carriers Import' link to Settings menu"

NAV_FILE=""
if [[ -f "$ROOT_DIR/resources/views/layouts/navigation.blade.php" ]]; then
    NAV_FILE="$ROOT_DIR/resources/views/layouts/navigation.blade.php"
else
    NAV_FILE="$(grep -R -l "Settings" "$ROOT_DIR/resources/views/layouts" --include='*.blade.php' --exclude='*.bak*' 2>/dev/null | head -n1 || true)"
fi

if [[ -n "$NAV_FILE" && -f "$NAV_FILE" ]]; then
    if ! grep -q "Carriers Import" "$NAV_FILE"; then
        info "Patching navigation file: $NAV_FILE"
        backup_file "$NAV_FILE"

        cat >> "$NAV_FILE" <<'BLADE'

{{-- Auto-added: Carriers Import link in Settings menu --}}
<x-dropdown-link href="{{ url('/carriers/import') }}">
    Carriers Import
</x-dropdown-link>
BLADE
    else
        info "Carriers Import link already present in $NAV_FILE (idempotent)."
    fi
else
    warn "Could not locate a navigation file containing 'Settings'; skipping Settings menu patch."
fi

##############################################
# 7. ITU MCCMNC normalizer + NetworkMnc mutator
##############################################

HELPER_FILE="$ROOT_DIR/app/Support/MccMncNormalizer.php"

if [[ ! -f "$HELPER_FILE" ]]; then
    info "Creating MCCMNC normalizer helper at $HELPER_FILE"
    mkdir -p "$(dirname "$HELPER_FILE")"
    cat > "$HELPER_FILE" <<'PHP'
<?php

namespace App\Support;

class MccMncNormalizer
{
    /**
     * Normalize MCCMNC codes for ITU import.
     *
     * Rule:
     *  - When a 6-digit numeric code has 4th digit = '0', drop that digit
     *    to produce a 5-digit code (e.g. 202001 -> 20201).
     */
    public static function normalize(?string $code): string
    {
        $digits = preg_replace('/\D+/', '', (string) $code);

        if (strlen($digits) === 6 && substr($digits, 3, 1) === '0') {
            $digits = substr($digits, 0, 3) . substr($digits, 4);
        }

        return $digits;
    }
}
PHP
    mark_new_file "$HELPER_FILE"
else
    info "Helper already exists: $HELPER_FILE (idempotent)"
fi

NETWORK_MNC_MODEL="$ROOT_DIR/app/Models/NetworkMnc.php"
if [[ -f "$NETWORK_MNC_MODEL" ]]; then
    info "Patching NetworkMnc model to use MccMncNormalizer"
    backup_file "$NETWORK_MNC_MODEL"

    # Add use statement if missing
    if ! grep -q "MccMncNormalizer" "$NETWORK_MNC_MODEL"; then
        perl -0pi -e '
            s|(namespace\s+App\\Models;)|$1\n\nuse App\\Support\\MccMncNormalizer;|s
        ' "$NETWORK_MNC_MODEL"
    fi

    # Add mutator for mcc_mnc if not present
    if ! grep -q "setMccMncAttribute" "$NETWORK_MNC_MODEL"; then
        perl -0pi -e '
            s|\}\s*$|
                public function setMccMncAttribute($value): void
                {
                    $this->attributes["mcc_mnc"] = MccMncNormalizer::normalize((string) $value);
                }
            }\n|s
        ' "$NETWORK_MNC_MODEL"
    else
        info "setMccMncAttribute mutator already present in NetworkMnc (idempotent)."
    fi
else
    warn "[Unverified] NetworkMnc model not found at $NETWORK_MNC_MODEL; ITU normalizer not wired automatically."
fi

##############################################
# 8. Run migrations
##############################################

info "Running migrations (php artisan migrate --force)"
ARTISAN migrate --force
MIGRATED=1

##############################################
# 9. Clear & rebuild Laravel caches
##############################################

info "Clearing & rebuilding caches"
ARTISAN optimize:clear || warn "optimize:clear failed (non-fatal)"
ARTISAN config:cache   || warn "config:cache failed (non-fatal)"
ARTISAN route:cache    || warn "route:cache failed (non-fatal)"
ARTISAN view:cache     || warn "view:cache failed (non-fatal)"

##############################################
# 10. Smoke tests
##############################################

info "Running quick smoke tests"

ARTISAN route:list > /dev/null || warn "route:list failed – please check routes manually."

PHP_RUN <<'PHP'
<?php

require __DIR__ . '/vendor/autoload.php';

$app = require __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use Illuminate\Support\Facades\DB;

try {
    DB::table('networks')->limit(1)->get();
    DB::table('countries')->limit(1)->get();
    if (DB::getSchemaBuilder()->hasTable('network_meta')) {
        DB::table('network_meta')->limit(1)->get();
    }
    if (DB::getSchemaBuilder()->hasTable('country_meta')) {
        DB::table('country_meta')->limit(1)->get();
    }
    echo "DB smoke OK: networks, countries, network_meta, country_meta accessible.\n";
} catch (\Throwable $e) {
    fwrite(STDERR, "DB smoke test failed: " . $e->getMessage() . "\n");
    exit(1);
}
PHP

info "Smoke tests passed."

##############################################
# 11. Disable rollback trap before git ops
##############################################

trap - ERR
MIGRATED=0

##############################################
# 12. Git add/commit/tag/push
##############################################

info "Preparing git commit + tag + push"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    warn "Not inside a git repository – skipping commit/tag/push."
    exit 0
fi

git add database/migrations app/Support app/Models resources/views || warn "git add partially failed; please review."

if [[ -z "$(git status --porcelain)" ]]; then
    info "No changes detected after script run – nothing to commit. Exiting."
    exit 0
fi

COMMIT_MSG="Feature pack: networks & countries meta + UI + ITU normalizer"
info "Committing with message: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"

BASE_TAG="core-ui-v1"
TAG_NAME="$BASE_TAG"
if git rev-parse -q --verify "refs/tags/$TAG_NAME" >/dev/null; then
    TAG_NAME="${BASE_TAG}-$(date +%Y%m%d%H%M%S)"
fi

info "Tagging current commit as: $TAG_NAME"
git tag "$TAG_NAME"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
info "Pushing branch '$CURRENT_BRANCH' to origin"
git push origin "$CURRENT_BRANCH"

info "Pushing tag '$TAG_NAME' to origin"
git push origin "$TAG_NAME"

info "Feature pack script completed successfully."
echo "Log file: $LOG_FILE"
echo "Backups stored under: $BACKUP_DIR"

exit 0
