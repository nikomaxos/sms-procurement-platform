#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

### 1) Make countries/edit.blade.php robust to $mccs being array or Collection
V="resources/views/countries/edit.blade.php"
if [ -f "$V" ]; then
  b "$V"
  # If our normalizer snippet isn't present, inject it at the very top.
  if ! grep -q 'MCCS_NORMALIZER_ROUND19' "$V"; then
    tmp="$(mktemp)"
    cat > "$tmp" <<'BLADE'
{{-- MCCS_NORMALIZER_ROUND19 --}}
@php
    // Normalize $mccs to a Collection regardless of what the controller passed.
    // Then prepare a safe, de-duplicated printable string.
    $mccs = collect($mccs ?? ($country->mccs ?? []));
    $mccs_list = $mccs->pluck('mcc')->filter()->unique()->values();
    $mccs_str = $mccs_list->implode(', ');
@endphp

BLADE
    cat "$tmp" "$V" > "$V.new" && mv "$V.new" "$V"
    rm -f "$tmp"
  fi

  # Common mistake: using PHP implode() directly on a Collection.
  # Convert "implode(', ', $mccs->pluck('mcc'))" -> "$mccs->pluck('mcc')->implode(', ')"
  sed -i -E "s/implode\((['\"][^'\"]*['\"]),\s*\$mccs->pluck\('mcc'\)\)/\$mccs->pluck('mcc')->implode(\1)/g" "$V"

  # If the template prints $mccs directly via implode somewhere else, offer $mccs_str
  # (we don't force a replacement; the normalizer defines $mccs_str for safe use).
fi

### 2) Provide a tiny importer page if missing (GET /carriers/import)
IV="resources/views/carriers/import.blade.php"
if [ ! -f "$IV" ]; then
  mkdir -p "$(dirname "$IV")"
  cat > "$IV" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Carriers Import</h2>
  </x-slot>

  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded bg-green-50 text-green-700 px-4 py-2">{{ session('status') }}</div>
    @endif
    @if ($errors->any())
      <div class="mb-4 rounded bg-red-50 text-red-700 px-4 py-2">
        <ul class="list-disc pl-5">
          @foreach ($errors->all() as $e)
            <li>{{ $e }}</li>
          @endforeach
        </ul>
      </div>
    @endif

    <form method="POST" action="{{ route('carriers.import') }}" class="space-y-4 bg-white border rounded-lg p-4">
      @csrf
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Source</label>
        <select name="source" class="rounded border px-3 py-2">
          <option value="itu" selected>ITU (public JSON mirror)</option>
        </select>
      </div>
      <div class="flex items-center gap-2">
        <input id="fresh" type="checkbox" name="fresh" value="1" class="rounded border">
        <label for="fresh" class="text-sm text-gray-700">Fresh import (truncate links, keep countries/networks)</label>
      </div>
      <div class="flex items-center gap-3">
        <button class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">
          Run Import
        </button>
        <a href="{{ route('networks.index') }}" class="rounded border px-4 py-2 bg-white hover:bg-gray-50">Back</a>
      </div>
    </form>
  </div>
</x-app-layout>
BLADE
fi

### 3) Rebuild caches
$DC exec -T app sh -lc '
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
'
echo "Round19: countries/edit normalized for $mccs (array/Collection) and importer view ensured."
