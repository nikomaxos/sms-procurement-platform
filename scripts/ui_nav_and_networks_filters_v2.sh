#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/ui_nav_and_networks_filters_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/ui_nav_and_networks_filters_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR" | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE" | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

NAV_FILE="$ROOT_DIR/resources/views/layouts/navigation.blade.php"
NET_FILE="$ROOT_DIR/resources/views/networks/index.blade.php"

if [ ! -f "$NAV_FILE" ]; then
  echo "ERROR: $NAV_FILE not found" | tee -a "$LOG_FILE"
  exit 1
fi

if [ ! -f "$NET_FILE" ]; then
  echo "ERROR: $NET_FILE not found" | tee -a "$LOG_FILE"
  exit 1
fi

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

restore_backups() {
  for f in "${MOD_FILES[@]}"; do
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    if [ -f "$backup_path" ]; then
      cp "$backup_path" "$f"
      echo "   - Restored $f from $backup_path" | tee -a "$LOG_FILE"
    fi
  done
}

on_error() {
  local line="$1"
  echo "ERROR: ${SCRIPT_NAME} failed at line ${line}" | tee -a "$LOG_FILE"
  echo "==> Rolling back changes..." | tee -a "$LOG_FILE"
  restore_backups
  echo "WARN: Rollback complete. See $LOG_FILE for details." | tee -a "$LOG_FILE"
  exit 1
}
trap 'on_error $LINENO' ERR

# -------------------------------------------------------------------
# 1) Backups
# -------------------------------------------------------------------
backup_file "$NAV_FILE"
backup_file "$NET_FILE"

# -------------------------------------------------------------------
# 2) Rewrite navigation.blade.php
#    - Align Settings with other items (same flex frame)
#    - Settings dropdown opens downward (top-full + mt-2)
#    - Carriers Import visible when user is admin (is_admin OR usertype='admin')
# -------------------------------------------------------------------
echo "==> Rewriting navigation layout" | tee -a "$LOG_FILE"

cat > "$NAV_FILE" <<'BLADE'
<nav x-data="{ open: false }" class="bg-white border-b border-gray-100">
    @php
        $user = auth()->user();
        $isAdmin = $user && (
            (!empty($user->is_admin)) ||
            (($user->usertype ?? null) === 'admin')
        );
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
                <div class="hidden space-x-8 sm:-my-px sm:ms-10 sm:flex items-center">
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
                            class="relative flex items-center"
                        >
                            <x-nav-link href="#"
                                :active="request()->routeIs('settings.*') || request()->is('carriers/import') || request()->routeIs('users.*')">
                                <span class="inline-flex items-center">
                                    {{ __('Settings') }}
                                    <svg class="ms-1 h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"
                                         fill="currentColor" aria-hidden="true">
                                        <path fill-rule="evenodd"
                                              d="M5.23 7.21a.75.75 0 011.06.02L10 10.94l3.71-3.71a.75.75 0 111.06 1.06l-4.24 4.24a.75.75 0 01-1.06 0L5.21 8.27a.75.75 0 01.02-1.06z"
                                              clip-rule="evenodd" />
                                    </svg>
                                </span>
                            </x-nav-link>

                            <div
                                x-cloak
                                x-show="openSettings"
                                x-transition
                                class="absolute left-0 top-full mt-2 z-50 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5"
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
                        <button
                            class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium
                                   rounded-md text-gray-500 bg-white hover:text-gray-700 focus:outline-none
                                   transition ease-in-out duration-150">
                            <div>{{ Auth::user()->name }}</div>

                            <div class="ms-1">
                                <svg class="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg"
                                     viewBox="0 0 20 20">
                                    <path fill-rule="evenodd"
                                          d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                                          clip-rule="evenodd" />
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
                <button @click="open = ! open"
                        class="inline-flex items-center justify-center p-2 rounded-md text-gray-400
                               hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:bg-gray-100
                               focus:text-gray-500 transition duration-150 ease-in-out">
                    <svg class="h-6 w-6" stroke="currentColor" fill="none" viewBox="0 0 24 24">
                        <path :class="{'hidden': open, 'inline-flex': ! open }" class="inline-flex"
                              stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                              d="M4 6h16M4 12h16M4 18h16" />
                        <path :class="{'hidden': ! open, 'inline-flex': open }" class="hidden"
                              stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
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
# 3) Rewrite networks/index.blade.php
#    - Filters in a single row (md:grid-cols-6 + col spans)
#    - MCCMNC filter kept, "starts with"
# -------------------------------------------------------------------
echo "==> Rewriting networks index view" | tee -a "$LOG_FILE"

cat > "$NET_FILE" <<'BLADE'
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
        $mccmnc         = trim((string) $request->input('mccmnc', ''));
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

        if ($mccmnc !== '') {
            $needle = $mccmnc;
            $query->whereExists(function ($sub) use ($needle) {
                $sub->from('network_mncs as nmn')
                    ->whereColumn('nmn.network_id', 'networks.id')
                    ->whereRaw(
                        "CAST(nmn.mcc AS text) || LPAD(CAST(nmn.mnc AS text), 2, '0') LIKE ?",
                        [$needle . '%']
                    );
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
            {{-- Filters in one row: q, country, mccmnc, non-operational, actions --}}
            <form method="GET" action="{{ route('networks.index') }}" id="networks-filter-form">
                <div class="grid grid-cols-1 md:grid-cols-6 gap-4 items-end">
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

                    {{-- MCCMNC filter (starts with) --}}
                    <div>
                        <label for="filter_mccmnc" class="block text-sm font-medium text-gray-700">
                            MCCMNC
                        </label>
                        <input
                            type="text"
                            id="filter_mccmnc"
                            name="mccmnc"
                            value="{{ $mccmnc }}"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            placeholder="e.g. 20201"
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

                    {{-- Actions: apply/reset --}}
                    <div class="flex gap-2 justify-start md:justify-end">
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
                    </div>
                </div>

                {{-- Preserve sort/direction/per_page across filter submissions --}}
                <input type="hidden" name="sort" id="networks_sort" value="{{ $sort }}">
                <input type="hidden" name="direction" id="networks_direction" value="{{ $direction }}">
                <input type="hidden" name="per_page" id="networks_per_page" value="{{ $perPage }}">
            </form>

            {{-- Results table --}}
            <div class="overflow-x-auto rounded-lg border bg-white mt-4">
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
                            <th class="px-4 py-3">
                                MCCs
                            </th>
                            <th class="px-4 py-3">
                                MNCs
                            </th>
                            <th class="px-4 py-3">
                                Non-operational
                            </th>
                            <th class="px-4 py-3">
                                Notes
                            </th>
                            <th class="px-4 py-3 text-right">
                                Actions
                            </th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200">
                        @forelse ($networks as $network)
                            @php
                                $mccs = $network->mncs
                                    ->pluck('mcc')
                                    ->map(function ($val) {
                                        return str_pad((string) $val, 3, '0', STR_PAD_LEFT);
                                    })
                                    ->unique()
                                    ->values();

                                $mncs = $network->mncs
                                    ->pluck('mnc')
                                    ->map(function ($val) {
                                        return str_pad((string) $val, 2, '0', STR_PAD_LEFT);
                                    })
                                    ->unique()
                                    ->values();
                            @endphp
                            <tr class="text-sm text-gray-700">
                                <td class="px-4 py-2 whitespace-nowrap">
                                    <div class="font-medium text-gray-900">
                                        {{ $network->country_name ?? $network->country->name ?? '—' }}
                                    </div>
                                    <div class="text-xs text-gray-500">
                                        {{ $network->country_iso2 ?? $network->country->iso2 ?? '' }}
                                    </div>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    <div class="font-medium text-gray-900">
                                        {{ $network->name }}
                                    </div>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    <div class="flex flex-wrap gap-1">
                                        @forelse ($mccs as $mcc)
                                            <span class="inline-flex items-center rounded-full bg-blue-100 px-2 py-0.5 text-xs font-semibold text-blue-800">
                                                {{ $mcc }}
                                            </span>
                                        @empty
                                            <span class="text-xs text-gray-400">—</span>
                                        @endforelse
                                    </div>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    <div class="flex flex-wrap gap-1">
                                        @forelse ($mncs as $mnc)
                                            <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs font-semibold text-gray-800">
                                                {{ $mnc }}
                                            </span>
                                        @empty
                                            <span class="text-xs text-gray-400">—</span>
                                        @endforelse
                                    </div>
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    @if ($network->non_operational)
                                        <span class="inline-flex rounded-full bg-red-100 px-2 py-0.5 text-xs font-semibold text-red-700">
                                            Non-operational
                                        </span>
                                    @else
                                        <span class="inline-flex rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-700">
                                            Operational
                                        </span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap max-w-xs">
                                    @if ($network->meta_notes)
                                        <span class="text-xs text-gray-700 line-clamp-2">
                                            {{ $network->meta_notes }}
                                        </span>
                                    @else
                                        <span class="text-xs text-gray-400">—</span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-right">
                                    <div class="flex items-center justify-end gap-2">
                                        <a href="{{ route('networks.edit', $network) }}"
                                           class="inline-flex items-center rounded-md border border-gray-300 bg-white px-3 py-1 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50">
                                            Edit
                                        </a>
                                        <form method="POST" action="{{ route('networks.destroy', $network) }}"
                                              onsubmit="return confirm('Are you sure you want to delete this network?');">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit"
                                                    class="inline-flex items-center rounded-md border border-red-300 bg-white px-3 py-1 text-xs font-medium text-red-700 shadow-sm hover:bg-red-50">
                                                Delete
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" class="px-4 py-6 text-center text-sm text-gray-500">
                                    No networks found.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{-- Pagination + per-page selector at bottom --}}
            <div class="mt-4 flex flex-col md:flex-row md:items-center md:justify-between gap-3">
                <div class="text-sm text-gray-600">
                    @if ($networks->total() > 0)
                        Showing
                        <span class="font-semibold">{{ $networks->firstItem() }}</span>
                        to
                        <span class="font-semibold">{{ $networks->lastItem() }}</span>
                        of
                        <span class="font-semibold">{{ $networks->total() }}</span>
                        networks
                    @else
                        No networks to display.
                    @endif
                </div>
                <div>
                    {{ $networks->links() }}
                </div>
            </div>

            <div class="mt-2 flex items-center justify-end space-x-2">
                <label for="networks_per_page_select" class="text-xs text-gray-600">
                    Results per page:
                </label>
                <select
                    id="networks_per_page_select"
                    class="rounded-md border-gray-300 text-xs shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                >
                    @foreach ([10, 25, 50, 100, 200] as $opt)
                        <option value="{{ $opt }}" @selected($perPage === $opt)>{{ $opt }}</option>
                    @endforeach
                </select>
            </div>
        </div>
    </div>

    {{-- Country typeahead keyboard navigation + per-page handler --}}
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const input     = document.getElementById('filter_country_name');
            const hiddenId  = document.getElementById('filter_country_id');
            const list      = document.getElementById('country_suggestions');
            const form      = document.getElementById('networks-filter-form');
            const perSelect = document.getElementById('networks_per_page_select');
            const perHidden = document.getElementById('networks_per_page');

            if (perSelect && perHidden && form) {
                perSelect.addEventListener('change', function () {
                    perHidden.value = this.value;
                    form.submit();
                });
            }

            if (!input || !hiddenId || !list) {
                return;
            }

            let items = Array.from(list.querySelectorAll('li'));
            let activeIndex = -1;

            function resetHighlight() {
                items.forEach(li => li.classList.remove('bg-indigo-600', 'text-white'));
            }

            function highlightItem(li) {
                resetHighlight();
                if (li) {
                    li.classList.add('bg-indigo-600', 'text-white');
                }
            }

            function visibleItems() {
                return items.filter(li => !li.classList.contains('hidden'));
            }

            function openList() {
                list.classList.remove('hidden');
            }

            function closeList() {
                list.classList.add('hidden');
                activeIndex = -1;
                resetHighlight();
            }

            function selectItem(li) {
                if (!li) return;
                const id    = li.getAttribute('data-id') || '';
                const label = li.getAttribute('data-label') || '';

                hiddenId.value = id;
                input.value    = label;

                closeList();

                if (form) form.submit();
            }

            input.addEventListener('focus', function () {
                if (input.value.trim() !== '') {
                    openList();
                }
            });

            input.addEventListener('input', function () {
                const term = input.value.toLowerCase();

                items.forEach(li => {
                    const label = (li.getAttribute('data-label') || '').toLowerCase();
                    if (!term || label.includes(term)) {
                        li.classList.remove('hidden');
                    } else {
                        li.classList.add('hidden');
                    }
                });

                const vis = visibleItems();
                if (vis.length > 0) {
                    openList();
                } else {
                    closeList();
                }
                activeIndex = -1;
                resetHighlight();
            });

            input.addEventListener('keydown', function (e) {
                const vis = visibleItems();
                if (!vis.length) return;

                if (e.key === 'ArrowDown') {
                    e.preventDefault();
                    activeIndex = (activeIndex + 1) % vis.length;
                    highlightItem(vis[activeIndex]);
                } else if (e.key === 'ArrowUp') {
                    e.preventDefault();
                    activeIndex = (activeIndex - 1 + vis.length) % vis.length;
                    highlightItem(vis[activeIndex]);
                } else if (e.key === 'Enter') {
                    if (activeIndex >= 0 && activeIndex < vis.length) {
                        e.preventDefault();
                        selectItem(vis[activeIndex]);
                    }
                } else if (e.key === 'Escape') {
                    closeList();
                }
            });

            list.addEventListener('click', function (e) {
                const li = e.target.closest('li[data-id]');
                if (!li) return;
                selectItem(li);
            });

            document.addEventListener('click', function (e) {
                if (!list.contains(e.target) && e.target !== input) {
                    closeList();
                }
            });
        });
    </script>
</x-app-layout>
BLADE

# -------------------------------------------------------------------
# 4) Clear & cache views
# -------------------------------------------------------------------
echo "==> Clearing & caching Blade views via docker compose (service: app)" | tee -a "$LOG_FILE"
if docker compose ps app >/dev/null 2>&1; then
  docker compose exec -T app php artisan view:clear  | tee -a "$LOG_FILE" || true
  docker compose exec -T app php artisan view:cache  | tee -a "$LOG_FILE" || true
else
  echo "WARN: docker compose service 'app' not found or not running; skipping artisan view cache" | tee -a "$LOG_FILE"
fi

# -------------------------------------------------------------------
# 5) Git commit + tag + push (best-effort push, no rollback on push failure)
# -------------------------------------------------------------------
cd "$ROOT_DIR"
if git diff --quiet -- resources/views/layouts/navigation.blade.php resources/views/networks/index.blade.php; then
  echo "==> No changes detected, nothing to commit." | tee -a "$LOG_FILE"
else
  echo "==> Committing and tagging changes..." | tee -a "$LOG_FILE"
  git add resources/views/layouts/navigation.blade.php resources/views/networks/index.blade.php

  COMMIT_MSG="ui(nav+networks): align Settings & single-row filters v2"
  if git commit -m "$COMMIT_MSG" | tee -a "$LOG_FILE"; then
    TAG="ui-nav-networks-${TS}"
    git tag "$TAG" || true
    git push origin main  | tee -a "$LOG_FILE" || echo "WARN: git push origin main failed" | tee -a "$LOG_FILE"
    git push origin "$TAG" | tee -a "$LOG_FILE" || echo "WARN: git push origin $TAG failed" | tee -a "$LOG_FILE"
  else
    echo "WARN: git commit failed (probably no changes to commit)" | tee -a "$LOG_FILE"
  fi
fi

echo "==> ${SCRIPT_NAME} completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
