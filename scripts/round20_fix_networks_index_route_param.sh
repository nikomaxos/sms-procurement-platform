#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

F="resources/views/networks/index.blade.php"
b "$F"; mkdir -p "$(dirname "$F")"

cat > "$F" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded bg-green-50 text-green-700 px-4 py-2">{{ session('status') }}</div>
    @endif

    <div class="mb-4">
      <a href="{{ route('networks.create') }}"
         class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">
        Create Network
      </a>
    </div>

    <div class="overflow-x-auto bg-white border rounded-lg">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
            <th class="px-4 py-3">Name</th>
            <th class="px-4 py-3">Country</th>
            <th class="px-4 py-3">MCCs</th>
            <th class="px-4 py-3">MNCs</th>
            <th class="px-4 py-3">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          @forelse($networks as $net)
            @php
              $mccs = optional($net->mncs)->pluck('mcc')->filter()->unique()->implode(', ');
              $mncs = optional($net->mncs)->pluck('mnc')->filter()->unique()->implode(', ');
            @endphp
            <tr class="text-sm">
              <td class="px-4 py-2">{{ $net->name }}</td>
              <td class="px-4 py-2">{{ $net->country->name ?? '—' }}</td>
              <td class="px-4 py-2">{{ $mccs }}</td>
              <td class="px-4 py-2">{{ $mncs }}</td>
              <td class="px-4 py-2">
                <a href="{{ route('networks.edit', $net) }}"
                   class="text-indigo-600 hover:underline">Edit</a>
                <form method="POST" action="{{ route('networks.destroy', $net) }}" class="inline"
                      onsubmit="return confirm('Delete this network?');">
                  @csrf @method('DELETE')
                  <button class="text-red-600 hover:underline ml-3" type="submit">Delete</button>
                </form>
              </td>
            </tr>
          @empty
            <tr><td class="px-4 py-3 text-gray-500" colspan="5">No networks found.</td></tr>
          @endforelse
        </tbody>
      </table>
    </div>

    <div class="mt-4">
      {{ method_exists($networks,'links') ? $networks->withQueryString()->links() : '' }}
    </div>
  </div>
</x-app-layout>
BLADE

# Rebuild caches inside the app container
$DC exec -T app sh -lc '
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'
echo "Round20: networks/index.blade.php replaced and caches rebuilt."
