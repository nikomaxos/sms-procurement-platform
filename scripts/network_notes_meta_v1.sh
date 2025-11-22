#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/network_notes_meta_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/network_notes_meta_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR" | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE" | tee -a "$LOG_FILE"
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

rollback() {
  echo "==> Rolling back modified files..." | tee -a "$LOG_FILE"

  for f in "${MOD_FILES[@]}"; do
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    if [ -f "$backup_path" ]; then
      cp "$backup_path" "$f"
      echo "   - Restored $f from $backup_path" | tee -a "$LOG_FILE"
    fi
  done

  if [ "${#NEW_FILES[@]}" -gt 0 ]; then
    echo "==> Removing newly created files..." | tee -a "$LOG_FILE"
    for nf in "${NEW_FILES[@]}"; do
      if [ -f "$nf" ]; then
        rm -f "$nf"
        echo "   - Removed new file $nf" | tee -a "$LOG_FILE"
      fi
    done
  fi
}

on_error() {
  local line="$1"
  echo "WARN: Error occurred at line $line. Starting rollback." | tee -a "$LOG_FILE"
  rollback
  echo "WARN: Rollback complete. See $LOG_FILE for details." | tee -a "$LOG_FILE"
  exit 1
}
trap 'on_error $LINENO' ERR

run_artisan() {
  local cmd=("$@")
  echo "==> Running artisan: ${cmd[*]}" | tee -a "$LOG_FILE"

  if command -v docker >/dev/null 2>&1 && docker compose ps >/dev/null 2>&1; then
    if docker compose ps --services 2>/dev/null | grep -qx "app"; then
      # Try through app service first, fall back to local php
      docker compose exec -T app php artisan "${cmd[@]}" 2>>"$LOG_FILE" || php artisan "${cmd[@]}" 2>>"$LOG_FILE" || true
      return 0
    fi
  fi

  php artisan "${cmd[@]}" 2>>"$LOG_FILE" || true
}

NETWORK_MODEL="$ROOT_DIR/app/Models/Network.php"
NETWORK_META_MODEL="$ROOT_DIR/app/Models/NetworkMeta.php"
NETWORKS_CONTROLLER="$ROOT_DIR/app/Http/Controllers/NetworksController.php"
NETWORKS_EDIT_VIEW="$ROOT_DIR/resources/views/networks/edit.blade.php"

# Sanity checks
if [ ! -f "$NETWORK_MODEL" ]; then
  echo "ERROR: Network model not found at $NETWORK_MODEL" | tee -a "$LOG_FILE"
  exit 1
fi

if [ ! -f "$NETWORKS_CONTROLLER" ]; then
  echo "ERROR: NetworksController not found at $NETWORKS_CONTROLLER" | tee -a "$LOG_FILE"
  exit 1
fi

mkdir -p "$BACKUP_ROOT" 2>/dev/null || true

# Backups
backup_file "$NETWORK_MODEL"
backup_file "$NETWORKS_CONTROLLER"
if [ -f "$NETWORKS_EDIT_VIEW" ]; then
  backup_file "$NETWORKS_EDIT_VIEW"
else
  echo "==> Note: $NETWORKS_EDIT_VIEW does not exist; will create a fresh edit view." | tee -a "$LOG_FILE"
fi
if [ -f "$NETWORK_META_MODEL" ]; then
  backup_file "$NETWORK_META_MODEL"
fi

echo "==> Step 1: Ensure NetworkMeta model exists" | tee -a "$LOG_FILE"
if [ ! -f "$NETWORK_META_MODEL" ]; then
  cat > "$NETWORK_META_MODEL" <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkMeta extends Model
{
    protected $table = 'network_meta';

    protected $fillable = [
        'network_id',
        'non_operational',
        'notes',
    ];

    protected $casts = [
        'non_operational' => 'bool',
    ];

    public function network(): BelongsTo
    {
        return $this->belongsTo(Network::class);
    }
}
PHP
  NEW_FILES+=("$NETWORK_META_MODEL")
  echo "   - Created NetworkMeta model." | tee -a "$LOG_FILE"
else
  echo "   - NetworkMeta model already present; leaving as-is." | tee -a "$LOG_FILE"
fi

echo "==> Step 2: Add meta() relation on Network model" | tee -a "$LOG_FILE"
ROOT_DIR="$ROOT_DIR" NETWORK_MODEL="$NETWORK_MODEL" python3 <<'PY'
import os

root = os.environ['ROOT_DIR']
path = os.environ['NETWORK_MODEL']

with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

if 'function meta(' in src:
    print("   - meta() relation already exists on Network; skipping.")
else:
    idx = src.rfind('}')
    if idx == -1:
        raise SystemExit("No closing brace found in Network.php")
    insert_text = """

    public function meta()
    {
        return $this->hasOne(\\App\\Models\\NetworkMeta::class);
    }
"""
    new_src = src[:idx] + insert_text + "\n}\n"
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_src)
    print("   - Added meta() relation to Network.")
PY

echo "==> Step 3: Patch NetworksController@store/@update to handle notes" | tee -a "$LOG_FILE"
ROOT_DIR="$ROOT_DIR" NETWORKS_CONTROLLER="$NETWORKS_CONTROLLER" python3 <<'PY'
import os

path = os.environ['NETWORKS_CONTROLLER']
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

def ensure_import(src: str) -> str:
    if 'use App\\Models\\NetworkMeta;' in src:
        print("   - NetworkMeta import already present.")
        return src
    lines = src.splitlines(True)
    last_use = -1
    for i, line in enumerate(lines):
        if line.lstrip().startswith('use ') and 'App\\Models\\' in line:
            last_use = i
    if last_use == -1:
        for i, line in enumerate(lines):
            if line.startswith('namespace '):
                last_use = i
                break
    insert_line = "use App\\Models\\NetworkMeta;\\n"
    if last_use == -1:
        print("   - Inserting NetworkMeta import at file top.")
        return insert_line + src
    lines.insert(last_use + 1, insert_line)
    print("   - Inserted NetworkMeta import after existing model uses.")
    return ''.join(lines)

def replace_method(src: str, method_name: str, new_code: str) -> str:
    sig = f"public function {method_name}("
    sig_pos = src.find(sig)
    if sig_pos == -1:
        print(f"   ! Signature for {method_name} not found; leaving file unchanged for this method.")
        return src
    line_start = src.rfind('\n', 0, sig_pos)
    if line_start == -1:
        line_start = 0
    else:
        line_start += 1
    brace_pos = src.find('{', sig_pos)
    if brace_pos == -1:
        print(f"   ! Opening brace for {method_name} not found; leaving file unchanged for this method.")
        return src
    depth = 0
    i = brace_pos
    end_pos = None
    while i < len(src):
        ch = src[i]
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                end_pos = i
                break
        i += 1
    if end_pos is None:
        print(f"   ! Could not find end of {method_name} method; leaving file unchanged for this method.")
        return src
    new_segment = new_code
    print(f"   - Replaced {method_name}() method body.")
    return src[:line_start] + new_segment + src[end_pos + 1:]

store_code = """
    public function store(Request $request)
    {
        $data = $request->validate([
            'country_id' => 'required|integer|exists:countries,id',
            'name'       => 'required|string|max:255',
            'notes'      => 'nullable|string',
        ]);

        $network = new Network();
        $network->country_id = (int) $data['country_id'];
        $network->name       = $data['name'];

        if (schema_has_column('networks', 'lower_name')) {
            $network->lower_name = Str::lower($data['name']);
        }

        $network->save();

        $notes = trim((string) ($data['notes'] ?? ''));

        if ($notes !== '' || NetworkMeta::where('network_id', $network->id)->exists()) {
            NetworkMeta::updateOrCreate(
                ['network_id' => $network->id],
                ['notes'      => $notes]
            );
        }

        return back()->with('status', 'Network saved.');
    }
""".lstrip('\n')

update_code = """
    public function update(Request $request, Network $network)
    {
        $data = $request->validate([
            'country_id' => 'required|integer|exists:countries,id',
            'name'       => 'required|string|max:255',
            'notes'      => 'nullable|string',
        ]);

        $network->country_id = (int) $data['country_id'];
        $network->name       = $data['name'];

        if (schema_has_column('networks', 'lower_name')) {
            $network->lower_name = Str::lower($data['name']);
        }

        $network->save();

        $notes = trim((string) ($data['notes'] ?? ''));

        if ($notes !== '' || NetworkMeta::where('network_id', $network->id)->exists()) {
            NetworkMeta::updateOrCreate(
                ['network_id' => $network->id],
                ['notes'      => $notes]
            );
        } else {
            NetworkMeta::where('network_id', $network->id)->delete();
        }

        return back()->with('status', 'Network updated.');
    }
""".lstrip('\n')

src = ensure_import(src)
src = replace_method(src, "store", store_code)
src = replace_method(src, "update", update_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
PY

echo "==> Step 4: Rewrite networks edit view to include Notes" | tee -a "$LOG_FILE"
cat > "$NETWORKS_EDIT_VIEW" <<'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Edit Network: {{ $network->name }}
        </h2>
    </x-slot>

    <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        @includeIf('partials.flash_log')

        @if ($errors->any())
            <div class="mb-4 rounded border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
                <div class="mb-1 font-semibold">There were some problems with your input:</div>
                <ul class="list-disc list-inside space-y-1">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        <div class="bg-white p-6 shadow-sm sm:rounded-lg">
            <form method="POST" action="{{ route('networks.update', $network) }}">
                @csrf
                @method('PUT')

                @php
                    $countries = \App\Models\Country::orderBy('name')->get();
                @endphp

                <div class="mb-4">
                    <label for="country_id" class="block text-sm font-medium text-gray-700">
                        Country
                    </label>
                    <select
                        id="country_id"
                        name="country_id"
                        class="mt-1 block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        required
                    >
                        @foreach ($countries as $country)
                            <option value="{{ $country->id }}"
                                @selected(old('country_id', $network->country_id) == $country->id)
                            >
                                {{ $country->name }} ({{ $country->iso2 }})
                            </option>
                        @endforeach
                    </select>
                </div>

                <div class="mb-4">
                    <label for="name" class="block text-sm font-medium text-gray-700">
                        Name
                    </label>
                    <input
                        id="name"
                        name="name"
                        type="text"
                        value="{{ old('name', $network->name) }}"
                        class="mt-1 block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        required
                    >
                </div>

                <div class="mb-4">
                    <label for="notes" class="block text-sm font-medium text-gray-700">
                        Notes
                    </label>
                    <textarea
                        id="notes"
                        name="notes"
                        rows="4"
                        class="mt-1 block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        placeholder="Internal notes about this network"
                    >{{ old('notes', optional($network->meta)->notes) }}</textarea>
                </div>

                <div class="mt-6 flex items-center gap-3">
                    <button
                        type="submit"
                        class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                    >
                        Save
                    </button>
                    <a
                        href="{{ route('networks.index') }}"
                        class="inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50"
                    >
                        Cancel
                    </a>
                </div>
            </form>
        </div>
    </div>
</x-app-layout>
BLADE

echo "   - networks/edit.blade.php written." | tee -a "$LOG_FILE"

echo "==> Step 5: Clear & rebuild caches (best-effort)" | tee -a "$LOG_FILE"
run_artisan optimize:clear
run_artisan view:cache

echo "==> Script completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"

exit 0
