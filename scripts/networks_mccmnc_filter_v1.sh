#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/networks_mccmnc_filter_v1_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/networks_mccmnc_filter_v1_${TS}.log"

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

NET_INDEX="$ROOT_DIR/resources/views/networks/index.blade.php"

if [ ! -f "$NET_INDEX" ]; then
  echo "ERROR: networks index view not found at $NET_INDEX" | tee -a "$LOG_FILE"
  exit 1
fi

backup_file "$NET_INDEX"

echo "==> Rewriting networks index view with MCCMNC filter and per-network MCCs" | tee -a "$LOG_FILE"

cat > "$NET_INDEX" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Networks
        </h2>
    </x-slot>

    @php
        use App\Support\MccMncNormalizer;

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
            $normalized = MccMncNormalizer::normalize($mccmnc);

            if ($normalized !== '') {
                $query->whereExists(function ($sub) use ($normalized) {
                    $sub->from('network_mncs as nm2')
                        ->whereColumn('nm2.network_id', 'networks.id')
                        ->where('nm2.mcc_mnc', $normalized);
                });
            }
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

        {{-- Filters – single row: q, country typeahead, non-operational, MCCMNC --}}
        <div class="bg-white shadow-sm sm:rounded-lg p-4 space-y-4">
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

                    {{-- MCCMNC filter --}}
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
                        <th class="px-4 py-3">MCCs</th>
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
                                    @php
                                        // MCCs only from this network's own MNC rows
                                        $mccValues = $network->mncs
                                            ? $network->mncs->pluck('mcc')->filter(fn($v) => $v !== null)->unique()->sort()->values()
                                            : collect();
                                    @endphp
                                    @forelse ($mccValues as $mcc)
                                        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                                            {{ str_pad((string) $mcc, 3, '0', STR_PAD_LEFT) }}
                                        </span>
                                    @empty
                                        <span class="text-xs text-gray-400">—</span>
                                    @endforelse
                                </div>
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
                            <td colspan="7" class="px-4 py-6 text-center text-sm text-gray-500">
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

    {{-- Country typeahead + keyboard navigation (with highlight) --}}
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

echo "==> networks/index.blade.php rewritten." | tee -a "$LOG_FILE"

# Clear & rebuild Blade caches (best effort)
ARTISAN_SERVICE=""

if command -v docker >/dev/null 2>&1 && docker compose ps >/dev/null 2>&1; then
  if docker compose ps --services 2>/dev/null | grep -qx "app"; then
    ARTISAN_SERVICE="app"
  elif docker compose ps --services 2>/dev/null | grep -qx "sms-platform-app"; then
    ARTISAN_SERVICE="sms-platform-app"
  fi
fi

if [ -n "$ARTISAN_SERVICE" ]; then
  echo "==> Clearing & caching views via docker compose ($ARTISAN_SERVICE)" | tee -a "$LOG_FILE"
  docker compose exec -T "$ARTISAN_SERVICE" php artisan view:clear | tee -a "$LOG_FILE" || true
  docker compose exec -T "$ARTISAN_SERVICE" php artisan view:cache | tee -a "$LOG_FILE" || true
else
  echo "==> No artisan service detected; skipping view cache commands." | tee -a "$LOG_FILE"
fi

trap - ERR

echo "==> networks_mccmnc_filter_v1.sh completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE"                | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
