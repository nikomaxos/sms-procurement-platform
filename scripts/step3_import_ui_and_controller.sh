#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Step3: Carriers Import UI + controller wiring (idempotent)"

# 1) Controller
C=app/Http/Controllers/CarriersImportController.php
b "$C"; mkdir -p "$(dirname "$C")"
cat > "$C" <<'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use App\Services\CarrierImportService;

class CarriersImportController extends Controller
{
    /**
     * POST /carriers/import
     */
    public function run(Request $request, CarrierImportService $svc)
    {
        $data = $request->validate([
            'source'         => 'required|in:auto,itu,local',
            'fresh'          => 'nullable|boolean',
            'fresh_confirm'  => 'required_if:fresh,1|nullable',
        ], [
            'fresh_confirm.required_if' => 'You must confirm the clearing step when "fresh" is selected.',
        ]);

        $source = $data['source'] ?? 'auto';
        $fresh  = (bool)($data['fresh'] ?? false);

        // 60s lock to avoid double-trigger / concurrent imports
        $lock = Cache::lock('carriers:import:lock', 60);
        if (!$lock->get()) {
            return back()->with('error', 'An import is already running or was triggered in the last 60 seconds.');
        }

        try {
            $res = $svc->import($source, $fresh);
        } catch (\Throwable $e) {
            $lock->release();
            return back()->with('error', 'Import failed: '.$e->getMessage());
        } finally {
            // In case service threw after partial work, ensure lock is released
            optional($lock)->release();
        }

        // Normalize summary payload for the view
        $summary = [
            'ok' => (bool)($res['ok'] ?? false),
            'msg' => (string)($res['msg'] ?? ''),
            'createdCountries' => (int)($res['createdCountries'] ?? 0),
            'createdNetworks'  => (int)($res['createdNetworks'] ?? 0),
            'createdMncs'      => (int)($res['createdMncs'] ?? 0),
            'source' => $source,
            'fresh'  => $fresh,
        ];

        if (!$summary['ok']) {
            return back()->with('error', $summary['msg'] ?: 'Import completed with issues.')->with('summary', $summary);
        }

        return back()->with('status', 'Import completed successfully.')->with('summary', $summary);
    }
}
PHP

# 2) View
V=resources/views/carriers/import.blade.php
b "$V"; mkdir -p "$(dirname "$V")"
cat > "$V" <<'BLADE'
@extends('layouts.app')

@section('content')
<div class="max-w-3xl mx-auto p-6">
  <h1 class="text-2xl font-semibold mb-4">Carriers Import</h1>

  @if ($errors->any())
    <div class="mb-4 rounded border border-red-300 bg-red-50 p-3 text-red-800">
      <ul class="list-disc ms-5">
        @foreach ($errors->all() as $error)
          <li>{{ $error }}</li>
        @endforeach
      </ul>
    </div>
  @endif

  @if (session('error'))
    <div class="mb-4 rounded border border-red-300 bg-red-50 p-3 text-red-800">
      {{ session('error') }}
    </div>
  @endif

  @if (session('status'))
    <div class="mb-4 rounded border border-green-300 bg-green-50 p-3 text-green-800">
      {{ session('status') }}
    </div>
  @endif

  @php($summary = session('summary'))
  @if ($summary)
    <div class="mb-6 rounded border p-4 bg-white">
      <div class="font-medium mb-2">Summary</div>
      <dl class="grid grid-cols-2 gap-2 text-sm">
        <div><dt class="text-gray-500">Source</dt><dd class="font-medium">{{ $summary['source'] ?? 'auto' }}</dd></div>
        <div><dt class="text-gray-500">Fresh</dt><dd class="font-medium">{{ !empty($summary['fresh']) ? 'Yes' : 'No' }}</dd></div>
        <div><dt class="text-gray-500">Countries created</dt><dd class="font-medium">{{ $summary['createdCountries'] ?? 0 }}</dd></div>
        <div><dt class="text-gray-500">Networks created</dt><dd class="font-medium">{{ $summary['createdNetworks'] ?? 0 }}</dd></div>
        <div><dt class="text-gray-500">MNC links created</dt><dd class="font-medium">{{ $summary['createdMncs'] ?? 0 }}</dd></div>
        <div class="col-span-2"><dt class="text-gray-500">Message</dt><dd class="font-medium">{{ $summary['msg'] ?? '' }}</dd></div>
      </dl>
      <div class="mt-3 text-sm">
        <a class="underline text-blue-700" href="{{ route('countries.index') }}">Countries</a>
        &nbsp;·&nbsp;
        <a class="underline text-blue-700" href="{{ route('networks.index') }}">Networks</a>
      </div>
    </div>
  @endif

  <form method="POST" action="{{ route('carriers.import') }}" class="rounded border p-4 bg-white">
    @csrf

    <div class="mb-4">
      <label for="source" class="block text-sm font-medium mb-1">Data source</label>
      <select id="source" name="source" class="w-full border rounded p-2">
        <option value="auto" {{ old('source','auto')==='auto' ? 'selected' : '' }}>Auto (try remote, fallback local)</option>
        <option value="itu"  {{ old('source')==='itu' ? 'selected' : '' }}>Remote JSON (onomondo/ITU)</option>
        <option value="local" {{ old('source')==='local' ? 'selected' : '' }}>Local bundled fallback</option>
      </select>
      <p class="text-xs text-gray-500 mt-1">Auto fetches remote JSON; if unreachable, it uses the local bundled table.</p>
    </div>

    <div class="mb-4">
      <label class="inline-flex items-center gap-2">
        <input type="checkbox" name="fresh" value="1" {{ old('fresh') ? 'checked' : '' }}>
        <span class="text-sm font-medium">Clear existing MCC/MNC links first (“fresh”)</span>
      </label>
      <p class="text-xs text-gray-500 ms-6">
        This clears <code>country_mccs</code> and <code>network_mncs</code> only (countries/networks are kept).
      </p>
    </div>

    <div class="mb-6">
      <label class="inline-flex items-center gap-2">
        <input type="checkbox" name="fresh_confirm" value="1" {{ old('fresh_confirm') ? 'checked' : '' }}>
        <span class="text-sm">I understand the clearing step. (Required if “fresh” is ticked.)</span>
      </label>
    </div>

    <button type="submit" class="px-4 py-2 rounded bg-blue-600 text-white font-medium">
      Run import
    </button>
    <p class="text-xs text-gray-500 mt-2">If you click twice quickly, the action is locked for 60s to avoid duplicates.</p>
  </form>
</div>
@endsection
BLADE

# 3) Lint & warm caches inside the app container (or host if no container)
php -l "$C" >/dev/null 2>&1 || { echo "PHP lint failed for controller"; exit 1; }

$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l resources/views/carriers/import.blade.php || true
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
  php artisan route:list | grep -n "carriers/import" || true
' 2>/dev/null || {
  # Fallback to host PHP if not using containers
  php artisan optimize:clear
  php artisan view:cache
  php artisan route:cache
  php artisan route:list | grep -n "carriers/import" || true
}

echo "==> Step3 complete."
