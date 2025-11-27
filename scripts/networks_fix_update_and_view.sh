#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Patching NetworksController::update (country + MNC logic)"

cat > scripts/_patch_networks_update_tmp.php << 'PHP'
<?php

$file = __DIR__ . '/../app/Http/Controllers/NetworksController.php';

$code = file_get_contents($file);
if ($code === false) {
    fwrite(STDERR, "Cannot read $file\n");
    exit(1);
}

// Inject missing imports (Str + NetworkMnc) once, just after namespace
$imports = '';

if (strpos($code, 'use Illuminate\\Support\\Str;') === false) {
    $imports .= "use Illuminate\\Support\\Str;\n";
}
if (strpos($code, 'use App\\Models\\NetworkMnc;') === false) {
    $imports .= "use App\\Models\\NetworkMnc;\n";
}

if ($imports !== '') {
    $code = preg_replace(
        '/^namespace App\\\\Http\\\\Controllers;\\s*$/m',
        "namespace App\\Http\\Controllers;\n\n" . $imports,
        $code,
        1,
        $count
    );
    if ($count === 0) {
        fwrite(STDERR, "Failed to inject imports for Str/NetworkMnc\n");
        exit(1);
    }
}

// Replace update() method
$pattern = '/public function update\\s*\\([^)]*\\)\\s*\\)\\s*\\{.*?^\\s*\\}/ms';
if (!preg_match($pattern, $code)) {
    // more tolerant pattern if the above fails (no extra ")")
    $pattern = '/public function update\\s*\\([^)]*\\)\\s*\\{.*?^\\s*\\}/ms';
}

$replacement = <<<'PHPFUNC'
public function update(Request $request, Network $network)
    {
        $action = $request->input('action', 'save');

        $data = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'country_id' => ['nullable', 'integer', 'exists:countries,id'],
            'new_mcc'    => ['nullable', 'string', 'max:3'],
            'new_mnc'    => ['nullable', 'string', 'max:3'],
        ]);

        // Basic network fields
        $network->name       = $data['name'];
        $network->lower_name = Str::lower($data['name']);
        $network->country_id = $data['country_id'] ?? null;
        $network->save();

        // Handle add-MNC action (does NOT touch existing MNCs)
        if ($action === 'add_mnc' && !empty($data['new_mnc'])) {
            $mcc = $data['new_mcc'] ?? null;

            // If MCC not provided from form, derive from first existing pair if any
            if ($mcc === null || $mcc === '') {
                $first = $network->mncs()->first();
                $mcc   = $first?->mcc;
            }

            if ($mcc) {
                $cleanMnc = trim($data['new_mnc']);
                // normalize: drop leading zeros but keep at least one digit
                $cleanMnc = ltrim($cleanMnc, '0');
                if ($cleanMnc === '') {
                    $cleanMnc = '0';
                }

                NetworkMnc::firstOrCreate([
                    'network_id' => $network->id,
                    'mcc'        => $mcc,
                    'mnc'        => $cleanMnc,
                ]);
            }
        }

        $msg = $action === 'add_mnc'
            ? 'Network updated & MNC added.'
            : 'Network updated.';

        return redirect()
            ->route('networks.edit', $network)
            ->with('success', $msg);
    }
PHPFUNC;

$new = preg_replace($pattern, $replacement, $code, 1, $count);
if ($count === 0) {
    fwrite(STDERR, "update() not found or not replaced\n");
    exit(1);
}

file_put_contents($file, $new);
echo "Patched update() with country + MNC logic.\n";
PHP

# Run the patcher inside the app container
docker compose exec app sh -lc '
  cd /var/www/html &&
  php scripts/_patch_networks_update_tmp.php
'
rm scripts/_patch_networks_update_tmp.php

echo "==> Rewriting networks edit blade (add MNC frame with readonly MCC)"

cat > resources/views/networks/edit.blade.php << 'PHPBLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Edit Network
        </h2>
    </x-slot>

    <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
        @includeIf('partials.flash_log')

        <div class="bg-white shadow rounded-lg p-6 space-y-6">
            <form method="POST" action="{{ route('networks.update', $network) }}">
                @csrf
                @method('PUT')

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
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
                            <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    {{-- Country --}}
                    <div>
                        <label for="country_id" class="block text-sm font-medium text-gray-700">
                            Country
                        </label>
                        <select
                            id="country_id"
                            name="country_id"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        >
                            <option value="">-- Select country --</option>
                            @foreach($countries as $country)
                                <option
                                    value="{{ $country->id }}"
                                    @selected(old('country_id', $network->country_id) == $country->id)
                                >
                                    {{ $country->name }}
                                </option>
                            @endforeach
                        </select>
                        @error('country_id')
                            <p class="mt-1 text-xs text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                {{-- MCC/MNCs --}}
                <div class="border-t pt-4 mt-4 space-y-3">
                    <h3 class="text-sm font-semibold text-gray-700">Current MCC/MNCs</h3>

                    @php
                        $mncs = $network->mncs ?? collect();
                    @endphp

                    @if($mncs->count())
                        <div class="flex flex-wrap gap-2 mt-2">
                            @foreach($mncs as $pair)
                                @php
                                    $mcc = $pair->mcc ?? '';
                                    $mnc = $pair->mnc ?? '';
                                    $mncPadded = str_pad((string) $mnc, 2, '0', STR_PAD_LEFT);
                                @endphp
                                <span class="inline-flex items-center rounded-full bg-gray-100 px-3 py-1 text-xs font-medium text-gray-700">
                                    {{ $mcc }}{{ $mncPadded }}
                                </span>
                            @endforeach
                        </div>
                    @else
                        <p class="text-sm text-gray-500 mt-2">
                            No MCC/MNCs assigned to this network yet.
                        </p>
                    @endif

                    {{-- Simple MNC add frame --}}
                    <div class="mt-4 p-4 border rounded-md bg-gray-50 space-y-3">
                        <h4 class="text-xs font-semibold text-gray-600 uppercase tracking-wide">
                            Add MCC/MNC
                        </h4>

                        @php
                            // derive MCC from existing pairs (first one) if available
                            $defaultMcc = $mncs->first()->mcc ?? '';
                        @endphp

                        <div class="grid grid-cols-3 gap-3 items-end">
                            <div>
                                <label class="block text-xs font-medium text-gray-600">
                                    MCC (read-only)
                                </label>
                                <input
                                    type="text"
                                    name="new_mcc"
                                    value="{{ old('new_mcc', $defaultMcc) }}"
                                    readonly
                                    class="mt-1 block w-full rounded-md border-gray-300 bg-gray-100 text-xs shadow-sm"
                                >
                            </div>

                            <div>
                                <label class="block text-xs font-medium text-gray-600">
                                    MNC
                                </label>
                                <input
                                    type="text"
                                    name="new_mnc"
                                    value="{{ old('new_mnc') }}"
                                    placeholder="e.g. 01, 21"
                                    class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                                >
                            </div>

                            <div class="flex justify-end">
                                <button
                                    type="submit"
                                    name="action"
                                    value="add_mnc"
                                    class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md
                                           text-white bg-gray-700 hover:bg-gray-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-700"
                                >
                                    Add MNC
                                </button>
                            </div>
                        </div>

                        <p class="text-[11px] text-gray-500">
                            When you add an MNC, it will be stored for this network using the MCC shown above.
                        </p>
                    </div>
                </div>

                <div class="mt-6 flex items-center justify-between">
                    <a
                        href="{{ route('networks.index') }}"
                        class="inline-flex items-center text-sm text-gray-600 hover:text-gray-900"
                    >
                        Cancel
                    </a>

                    <button
                        type="submit"
                        name="action"
                        value="save"
                        class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md
                               text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2
                               focus:ring-indigo-500"
                    >
                        Save
                    </button>
                </div>
            </form>
        </div>
    </div>
</x-app-layout>
PHPBLADE

echo "==> PHP syntax check + clear caches inside app container"
docker compose exec app sh -lc '
  cd /var/www/html &&
  php -l app/Http/Controllers/NetworksController.php &&
  php artisan optimize:clear || true
'

echo "==> Done. Now test /networks and /networks/{id}/edit"
