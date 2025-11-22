#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/ui_nav_networks_countries_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/ui_nav_networks_countries_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR" | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE" | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

# -------------------------------------------------------------------
# Helpers: backup + rollback
# -------------------------------------------------------------------
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
  else
    echo "==> WARN: Tried to back up missing file $f" | tee -a "$LOG_FILE"
  fi
}

rollback() {
  echo "==> Rolling back modified files..." | tee -a "$LOG_FILE"
  for f in "${MOD_FILES[@]}"; do
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    if [ -f "$backup_path" ]; then
      cp "$backup_path" "$f"
      echo "   - Restored $f from $backup_path" | tee -a "$LOG_FILE"
    else
      echo "   - WARN: No backup found for $f" | tee -a "$LOG_FILE"
    fi
  done
  echo "WARN: Rollback complete. See $LOG_FILE for details." | tee -a "$LOG_FILE"
}

on_error() {
  local line="$1"
  echo "ERROR: ${SCRIPT_NAME} failed at line ${line}" | tee -a "$LOG_FILE"
  rollback
  exit 1
}

trap 'on_error $LINENO' ERR

# -------------------------------------------------------------------
# Targets
# -------------------------------------------------------------------
NAV_FILE="$ROOT_DIR/resources/views/layouts/navigation.blade.php"
NETWORKS_FILE="$ROOT_DIR/resources/views/networks/index.blade.php"
COUNTRIES_FILE="$ROOT_DIR/resources/views/countries/index.blade.php"

backup_file "$NAV_FILE"
backup_file "$NETWORKS_FILE"
backup_file "$COUNTRIES_FILE"

# -------------------------------------------------------------------
# 1) Rewrite navigation.blade.php
# -------------------------------------------------------------------
echo "==> Rewriting navigation layout (top menu + Settings dropdown)" | tee -a "$LOG_FILE"

cat > "$NAV_FILE" <<'BLADE'
<nav x-data="{ open: false }" class="bg-white border-b border-gray-100">
    @php
        $user = auth()->user();
        $isAdmin = $user && $user->usertype === 'admin';
    @endphp

    <!-- Primary Navigation Menu -->
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
            <div class="flex">
                <!-- Logo -->
                <div class="shrink-0 flex items-center">
                    <a href="{{ route('dashboard') }}">
                        <x-application-logo class="block h-9 w-auto fill-current text-gray-800" />
                    </a>
                </div>

                <!-- Navigation Links (left / basic menu) -->
                <div class="hidden space-x-8 sm:-my-px sm:ms-10 sm:flex">
                    <x-nav-link :href="route('dashboard')" :active="request()->routeIs('dashboard')">
                        {{ __('Dashboard') }}
                    </x-nav-link>

                    <x-nav-link :href="route('countries.index')" :active="request()->routeIs('countries.*')">
                        {{ __('Countries') }}
                    </x-nav-link>

                    <x-nav-link :href="route('networks.index')" :active="request()->routeIs('networks.*')">
                        {{ __('Networks') }}
                    </x-nav-link>

                    <!-- Settings dropdown (hover) -->
                    @auth
                        <div
                            x-data="{ openSettings: false }"
                            @mouseenter="openSettings = true"
                            @mouseleave="openSettings = false"
                            class="relative"
                        >
                            <x-nav-link href="#" :active="request()->routeIs('settings.*') || request()->is('carriers/import') || request()->routeIs('users.*')">
                                <span class="inline-flex items-center">
                                    {{ __('Settings') }}
                                    <svg class="ms-1 h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                                        <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 10.94l3.71-3.71a.75.75 0 111.06 1.06l-4.24 4.24a.75.75 0 01-1.06 0L5.21 8.27a.75.75 0 01.02-1.06z" clip-rule="evenodd" />
                                    </svg>
                                </span>
                            </x-nav-link>

                            <div
                                x-cloak
                                x-show="openSettings"
                                x-transition
                                class="absolute z-50 mt-2 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5"
                            >
                                <div class="py-1 text-sm text-gray-700">
                                    <a href="{{ route('settings.dropdowns.index') }}" class="block px-4 py-2 hover:bg-gray-100">
                                        {{ __('Drop Down Menus') }}
                                    </a>
                                    <a href="{{ route('settings.imap.edit') }}" class="block px-4 py-2 hover:bg-gray-100">
                                        {{ __('IMAP Settings') }}
                                    </a>
                                    @if($isAdmin)
                                        <a href="{{ url('/carriers/import') }}" class="block px-4 py-2 hover:bg-gray-100">
                                            {{ __('Carriers Import') }}
                                        </a>
                                        @if (\Illuminate\Support\Facades\Route::has('users.index'))
                                            <a href="{{ route('users.index') }}" class="block px-4 py-2 hover:bg-gray-100">
                                                {{ __('Users Management') }}
                                            </a>
                                        @endif
                                    @endif
                                </div>
                            </div>
                        </div>
                    @endauth
                </div>
            </div>

            <!-- User Dropdown (top-right) -->
            <div class="hidden sm:flex sm:items-center sm:ms-6">
                <x-dropdown align="right" width="48">
                    <x-slot name="trigger">
                        <button class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-gray-500 bg-white hover:text-gray-700 focus:outline-none transition ease-in-out duration-150">
                            <div>{{ Auth::user()->name }}</div>

                            <div class="ms-1">
                                <svg class="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                                </svg>
                            </div>
                        </button>
                    </x-slot>

                    <x-slot name="content">
                        <x-dropdown-link :href="route('profile.edit')">
                            {{ __('Profile') }}
                        </x-dropdown-link>

                        <!-- Authentication -->
                        <form method="POST" action="{{ route('logout') }}">
                            @csrf

                            <x-dropdown-link :href="route('logout')"
                                onclick="event.preventDefault(); this.closest('form').submit();">
                                {{ __('Log Out') }}
                            </x-dropdown-link>
                        </form>
                    </x-slot>
                </x-dropdown>
            </div>

            <!-- Hamburger -->
            <div class="-me-2 flex items-center sm:hidden">
                <button @click="open = ! open" class="inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:bg-gray-100 focus:text-gray-500 transition duration-150 ease-in-out">
                    <svg class="h-6 w-6" stroke="currentColor" fill="none" viewBox="0 0 24 24">
                        <path :class="{'hidden': open, 'inline-flex': ! open }" class="inline-flex" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                              d="M4 6h16M4 12h16M4 18h16" />
                        <path :class="{'hidden': ! open, 'inline-flex': open }" class="hidden" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                              d="M6 18L18 6M6 6l12 12" />
                    </svg>
                </button>
            </div>
        </div>
    </div>

    <!-- Responsive Navigation Menu (mobile) -->
    <div :class="{'block': open, 'hidden': ! open}" class="hidden sm:hidden">
        <div class="pt-2 pb-3 space-y-1">
            <x-responsive-nav-link :href="route('dashboard')" :active="request()->routeIs('dashboard')">
                {{ __('Dashboard') }}
            </x-responsive-nav-link>

            <x-responsive-nav-link :href="route('countries.index')" :active="request()->routeIs('countries.*')">
                {{ __('Countries') }}
            </x-responsive-nav-link>

            <x-responsive-nav-link :href="route('networks.index')" :active="request()->routeIs('networks.*')">
                {{ __('Networks') }}
            </x-responsive-nav-link>

            @auth
                <div class="border-t border-gray-200 mt-2 pt-2 space-y-1">
                    <span class="block px-4 py-2 text-xs font-semibold text-gray-500 uppercase">
                        {{ __('Settings') }}
                    </span>

                    <x-responsive-nav-link :href="route('settings.dropdowns.index')" :active="request()->routeIs('settings.dropdowns.*')">
                        {{ __('Drop Down Menus') }}
                    </x-responsive-nav-link>

                    <x-responsive-nav-link :href="route('settings.imap.edit')" :active="request()->routeIs('settings.imap.*')">
                        {{ __('IMAP Settings') }}
                    </x-responsive-nav-link>

                    @if($isAdmin)
                        <x-responsive-nav-link :href="url('/carriers/import')" :active="request()->is('carriers/import')">
                            {{ __('Carriers Import') }}
                        </x-responsive-nav-link>

                        @if (\Illuminate\Support\Facades\Route::has('users.index'))
                            <x-responsive-nav-link :href="route('users.index')" :active="request()->routeIs('users.*')">
                                {{ __('Users Management') }}
                            </x-responsive-nav-link>
                        @endif
                    @endif
                </div>
            @endauth
        </div>

        <!-- Responsive Settings Options -->
        <div class="pt-4 pb-1 border-t border-gray-200">
            <div class="px-4">
                <div class="font-medium text-base text-gray-800">{{ Auth::user()->name }}</div>
                <div class="font-medium text-sm text-gray-500">{{ Auth::user()->email }}</div>
            </div>

            <div class="mt-3 space-y-1">
                <x-responsive-nav-link :href="route('profile.edit')">
                    {{ __('Profile') }}
                </x-responsive-nav-link>

                <!-- Authentication -->
                <form method="POST" action="{{ route('logout') }}">
                    @csrf

                    <x-responsive-nav-link :href="route('logout')"
                        onclick="event.preventDefault(); this.closest('form').submit();">
                        {{ __('Log Out') }}
                    </x-responsive-nav-link>
                </form>
            </div>
        </div>
    </div>
</nav>
BLADE

# -------------------------------------------------------------------
# 2) Rewrite networks/index.blade.php completely
# -------------------------------------------------------------------
echo "==> Rewriting networks index view (filters row, MCC/MNC chips, notes, typeahead JS)" | tee -a "$LOG_FILE"

cat > "$NETWORKS_FILE" <<'BLADE'
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
        $mccmncRaw      = (string) $request->input('mccmnc', '');
        $mccmnc         = preg_replace('/\D+/', '', $mccmncRaw ?? '');
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

        // MCCMNC "starts with" filter
        if ($mccmnc !== '') {
            $query->whereHas('mncs', function ($q2) use ($mccmnc) {
                $q2->whereRaw(
                    "(CAST(mcc AS TEXT) || LPAD(CASE WHEN CHAR_LENGTH(CAST(mnc AS TEXT)) = 3 AND LEFT(CAST(mnc AS TEXT), 1) = '0' THEN SUBSTRING(CAST(mnc AS TEXT) FROM 2) ELSE CAST(mnc AS TEXT) END, 2, '0')) LIKE ?",
                    [$mccmnc . '%']
                );
            });
        }

        if ($sort === 'name') {
            $query->orderBy('networks.name', $direction)->orderBy('country_name', 'asc');
        } else {
            $query->orderBy('country_name', $direction)->orderBy('networks.name', 'asc');
            $sort = 'country';
        }

        $networks = $query->paginate($perPage)->appends($request->query());

        $countryNextDir = ($sort === 'country' && $direction === 'asc') ? 'desc' : 'asc';
        $nameNextDir    = ($sort === 'name' && $direction === 'asc') ? 'desc' : 'asc';
    @endphp

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        @includeIf('partials.flash_log')

        <div class="bg-white shadow-sm sm:rounded-lg p-4 space-y-4">

            {{-- Filters – single row on desktop: q, country, mccmnc, non-operational, actions --}}
            <form method="GET" action="{{ route('networks.index') }}" id="networks-filter-form">
                <div class="grid grid-cols-1 md:grid-cols-5 gap-4 items-end">
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

                    {{-- Country filter with typeahead --}}
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

                    {{-- MCCMNC filter (starts-with) --}}
                    <div>
                        <label for="filter_mccmnc" class="block text-sm font-medium text-gray-700">
                            MCCMNC
                        </label>
                        <input
                            type="text"
                            id="filter_mccmnc"
                            name="mccmnc"
                            inputmode="numeric"
                            pattern="[0-9]*"
                            value="{{ $mccmnc }}"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            placeholder="Starts with… e.g. 202"
                        >
                    </div>

                    {{-- Non-operational filter (last) --}}
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

                    {{-- Actions --}}
                    <div class="flex gap-2 justify-start md:justify-end">
                        <button
                            type="submit"
                            class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:ring-offset-1"
                        >
                            Apply filters
                        </button>
                        <a
                            href="{{ route('networks.index') }}"
                            class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                        >
                            Reset
                        </a>
                    </div>
                </div>

                <input type="hidden" name="sort" id="networks_sort" value="{{ $sort }}">
                <input type="hidden" name="direction" id="networks_direction" value="{{ $direction }}">
                <input type="hidden" name="per_page" id="networks_per_page" value="{{ $perPage }}">
            </form>

            <div class="overflow-x-auto rounded-lg border">
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
                                    Network
                                    @if ($sort === 'name')
                                        <span class="text-[10px] text-gray-500">
                                            {{ $direction === 'asc' ? '▲' : '▼' }}
                                        </span>
                                    @endif
                                </a>
                            </th>
                            <th class="px-4 py-3">MCCs</th>
                            <th class="px-4 py-3">MNCs</th>
                            <th class="px-4 py-3">Non-operational</th>
                            <th class="px-4 py-3">Notes</th>
                            <th class="px-4 py-3 text-right">Actions</th>
                        </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                        @forelse ($networks as $network)
                            @php
                                $mncs = $network->mncs ?? collect();
                                $mccs = $mncs->pluck('mcc')->filter()->unique()->sort()->values();
                            @endphp
                            <tr>
                                <td class="px-4 py-2 text-sm text-gray-900">
                                    @if ($network->country)
                                        {{ $network->country_name ?? $network->country->name }}
                                        @if ($network->country_iso2 ?? $network->country->iso2)
                                            <span class="text-xs text-gray-500">
                                                ({{ $network->country_iso2 ?? $network->country->iso2 }})
                                            </span>
                                        @endif
                                    @else
                                        <span class="text-xs text-gray-400">—</span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 text-sm text-gray-900">
                                    {{ $network->name }}
                                </td>
                                <td class="px-4 py-2 text-sm">
                                    <div class="flex flex-wrap gap-1">
                                        @forelse ($mccs as $mcc)
                                            <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs text-gray-700 border border-gray-200">
                                                {{ str_pad((string) $mcc, 3, '0', STR_PAD_LEFT) }}
                                            </span>
                                        @empty
                                            <span class="text-xs text-gray-400">—</span>
                                        @endforelse
                                    </div>
                                </td>
                                <td class="px-4 py-2 text-sm">
                                    <div class="flex flex-wrap gap-1">
                                        @forelse ($mncs as $mnc)
                                            @php
                                                $mncVal = (string) $mnc->mnc;
                                                if (strlen($mncVal) === 3 && substr($mncVal, 0, 1) === '0') {
                                                    $mncVal = substr($mncVal, 1);
                                                }
                                                $mncDisplay = str_pad($mncVal, 2, '0', STR_PAD_LEFT);
                                            @endphp
                                            <span class="inline-flex items-center rounded-full bg-indigo-50 px-2 py-0.5 text-xs text-indigo-700 border border-indigo-200">
                                                {{ $mncDisplay }}
                                            </span>
                                        @empty
                                            <span class="text-xs text-gray-400">—</span>
                                        @endforelse
                                    </div>
                                </td>
                                <td class="px-4 py-2 text-sm">
                                    @if ($network->non_operational)
                                        <span class="inline-flex items-center rounded-full bg-red-50 px-2 py-0.5 text-xs font-medium text-red-700 border border-red-200">
                                            Non-operational
                                        </span>
                                    @else
                                        <span class="inline-flex items-center rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-700 border border-emerald-200">
                                            Operational
                                        </span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 text-sm text-gray-700">
                                    {{ $network->meta_notes ? \Illuminate\Support\Str::limit($network->meta_notes, 80) : '—' }}
                                </td>
                                <td class="px-4 py-2 text-sm text-right">
                                    <div class="inline-flex items-center gap-2">
                                        <a
                                            href="{{ route('networks.edit', $network) }}"
                                            class="inline-flex items-center rounded border border-gray-300 bg-white px-2 py-1 text-xs text-gray-700 hover:bg-gray-50"
                                        >
                                            Edit
                                        </a>
                                        <form method="POST" action="{{ route('networks.destroy', $network) }}" onsubmit="return confirm('Delete this network?');">
                                            @csrf
                                            @method('DELETE')
                                            <button
                                                type="submit"
                                                class="inline-flex items-center rounded border border-red-300 bg-white px-2 py-1 text-xs text-red-700 hover:bg-red-50"
                                            >
                                                Delete
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" class="px-4 py-6 text-center text-gray-500 text-sm">
                                    No networks found.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div class="mt-4 flex flex-col md:flex-row items-center justify-between gap-3">
                <div class="text-xs text-gray-500">
                    @if ($networks->total())
                        Showing {{ $networks->firstItem() }}–{{ $networks->lastItem() }} of {{ $networks->total() }} results
                    @else
                        No results.
                    @endif
                </div>

                <div class="flex items-center gap-4">
                    <form method="GET" action="{{ route('networks.index') }}" class="flex items-center gap-2 text-xs">
                        <input type="hidden" name="q" value="{{ $q }}">
                        <input type="hidden" name="country_id" value="{{ $countryId }}">
                        <input type="hidden" name="country_label" value="{{ $countryLabel }}">
                        <input type="hidden" name="non_operational" value="{{ $nonOperational }}">
                        <input type="hidden" name="mccmnc" value="{{ $mccmnc }}">
                        <input type="hidden" name="sort" value="{{ $sort }}">
                        <input type="hidden" name="direction" value="{{ $direction }}">
                        <span>Per page:</span>
                        <select
                            name="per_page"
                            onchange="this.form.submit()"
                            class="rounded-md border-gray-300 text-xs shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        >
                            @foreach ([10, 25, 50, 100, 200] as $opt)
                                <option value="{{ $opt }}" @selected($perPage === $opt)>{{ $opt }}</option>
                            @endforeach
                        </select>
                    </form>

                    <div>
                        {{ $networks->links() }}
                    </div>
                </div>
            </div>
        </div>
    </div>

    @push('scripts')
        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const countryInput   = document.getElementById('filter_country_name');
                const countryIdInput = document.getElementById('filter_country_id');
                const suggestions    = document.getElementById('country_suggestions');

                if (!countryInput || !countryIdInput || !suggestions) {
                    return;
                }

                let activeIndex = -1;
                const items = () => Array.from(suggestions.querySelectorAll('li'));

                const clearActive = () => {
                    items().forEach(li => li.classList.remove('bg-indigo-600', 'text-white'));
                };

                const openList = () => {
                    if (items().length) {
                        suggestions.classList.remove('hidden');
                    }
                };

                const closeList = () => {
                    suggestions.classList.add('hidden');
                    activeIndex = -1;
                    clearActive();
                };

                const setActiveIndex = (index) => {
                    const els = items();
                    if (!els.length) {
                        activeIndex = -1;
                        return;
                    }

                    if (index < 0) {
                        index = 0;
                    } else if (index >= els.length) {
                        index = els.length - 1;
                    }

                    activeIndex = index;

                    els.forEach((li, i) => {
                        if (i === activeIndex) {
                            li.classList.add('bg-indigo-600', 'text-white');
                            li.scrollIntoView({ block: 'nearest' });
                        } else {
                            li.classList.remove('bg-indigo-600', 'text-white');
                        }
                    });
                };

                const chooseActive = () => {
                    const els = items();
                    if (activeIndex < 0 || activeIndex >= els.length) return;

                    const li = els[activeIndex];
                    countryInput.value   = li.dataset.label || li.textContent.trim();
                    countryIdInput.value = li.dataset.id || '';
                    closeList();
                };

                countryInput.addEventListener('focus', () => {
                    openList();
                });

                countryInput.addEventListener('input', () => {
                    countryIdInput.value = '';
                    activeIndex = -1;
                    clearActive();
                    openList();
                });

                countryInput.addEventListener('keydown', (e) => {
                    const els = items();
                    if (!els.length) return;

                    if (e.key === 'ArrowDown') {
                        e.preventDefault();
                        if (suggestions.classList.contains('hidden')) {
                            openList();
                        }
                        setActiveIndex(activeIndex + 1);
                    } else if (e.key === 'ArrowUp') {
                        e.preventDefault();
                        if (activeIndex <= 0) {
                            setActiveIndex(els.length - 1);
                        } else {
                            setActiveIndex(activeIndex - 1);
                        }
                    } else if (e.key === 'Enter') {
                        if (!suggestions.classList.contains('hidden') && activeIndex >= 0) {
                            e.preventDefault();
                            chooseActive();
                        }
                    } else if (e.key === 'Escape') {
                        closeList();
                    }
                });

                items().forEach((li, index) => {
                    li.addEventListener('mousedown', (e) => {
                        e.preventDefault();
                        activeIndex = index;
                        chooseActive();
                    });
                });

                document.addEventListener('click', (e) => {
                    if (!suggestions.contains(e.target) && e.target !== countryInput) {
                        closeList();
                    }
                });
            });
        </script>
    @endpush
</x-app-layout>
BLADE

# -------------------------------------------------------------------
# 3) Slimmer Apply/Reset buttons in countries index view
# -------------------------------------------------------------------
echo "==> Tweaking Countries filters button padding (thinner buttons)" | tee -a "$LOG_FILE"

# Apply filters button
perl -pi -e 's/class="inline-flex items-center px-4 py-2 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"/class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:ring-offset-1"/' "$COUNTRIES_FILE" || true

# Reset button (only change py from 2 to 1.5 if that exact pattern exists)
perl -pi -e 's/class="inline-flex items-center px-3 py-2 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"/class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"/' "$COUNTRIES_FILE" || true

# -------------------------------------------------------------------
# 4) Clear & cache views via Docker
# -------------------------------------------------------------------
echo "==> Clearing & caching Blade views via docker compose (service: app)" | tee -a "$LOG_FILE"

cd "$ROOT_DIR"

ARTISAN="docker compose exec -T app php artisan"

if $ARTISAN view:clear >>"$LOG_FILE" 2>&1; then
  echo "   - view:clear OK" | tee -a "$LOG_FILE"
else
  echo "   - WARN: view:clear failed (see log), continuing" | tee -a "$LOG_FILE"
fi

if $ARTISAN view:cache >>"$LOG_FILE" 2>&1; then
  echo "   - view:cache OK" | tee -a "$LOG_FILE"
else
  echo "   - WARN: view:cache failed (see log), continuing" | tee -a "$LOG_FILE"
fi

echo "==> ${SCRIPT_NAME} completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
