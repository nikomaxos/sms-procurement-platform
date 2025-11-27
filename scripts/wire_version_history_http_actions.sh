#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TIMESTAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR="$ROOT/backup_wire_version_history_http_actions_${TIMESTAMP}"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/wire_version_history_http_actions_${TIMESTAMP}.log"

ROUTES_FILE="$ROOT/routes/web.php"
CTRL_FILE="$ROOT/app/Http/Controllers/VersionHistorySnapshotsController.php"
VIEW_FILE="$ROOT/resources/views/settings/version-history.blade.php"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Working dir: $ROOT"
echo "==> Backup dir:  $BACKUP_DIR"
echo "==> Log file:    $LOG_FILE"

# --- Backups -------------------------------------------------------------
if [ -f "$ROUTES_FILE" ]; then
  cp "$ROUTES_FILE" "$BACKUP_DIR/web.php"
  echo "   [backup] $ROUTES_FILE -> $BACKUP_DIR/web.php"
fi

if [ -f "$CTRL_FILE" ]; then
  cp "$CTRL_FILE" "$BACKUP_DIR/VersionHistorySnapshotsController.php"
  echo "   [backup] $CTRL_FILE -> $BACKUP_DIR/VersionHistorySnapshotsController.php"
fi

if [ -f "$VIEW_FILE" ]; then
  cp "$VIEW_FILE" "$BACKUP_DIR/version-history.blade.php"
  echo "   [backup] $VIEW_FILE -> $BACKUP_DIR/version-history.blade.php"
else
  echo "   [ERROR] View file not found: $VIEW_FILE"
  echo "          Cannot proceed safely; exiting."
  exit 1
fi

# --- Ensure controller import in routes/web.php --------------------------
if ! grep -q "App\\\\Http\\\\Controllers\\\\VersionHistorySnapshotsController" "$ROUTES_FILE"; then
  echo "==> Adding use App\\Http\\Controllers\\VersionHistorySnapshotsController; to routes/web.php"
  # Insert after the last existing "use App\Http\Controllers\" line if possible
  if grep -n "use App\\\\Http\\\\Controllers\\\\.*;" "$ROUTES_FILE" >/dev/null 2>&1; then
    last_use_line=$(grep -n "use App\\\\Http\\\\Controllers\\\\.*;" "$ROUTES_FILE" | tail -n1 | cut -d: -f1)
    awk -v ins_line="$last_use_line" '
      NR == ins_line {
        print;
        print "use App\\Http\\Controllers\\VersionHistorySnapshotsController;";
        next;
      }
      { print }
    ' "$ROUTES_FILE" > "$ROUTES_FILE.tmp"
    mv "$ROUTES_FILE.tmp" "$ROUTES_FILE"
  else
    # No previous use imports, just append near top
    tmp="$ROUTES_FILE.tmp"
    {
      echo "<?php"
      echo "use App\\Http\\Controllers\\VersionHistorySnapshotsController;"
      sed '1d' "$ROUTES_FILE"
    } > "$tmp"
    mv "$tmp" "$ROUTES_FILE"
  fi
else
  echo "   [ok] Controller import already present in routes/web.php"
fi

# --- Ensure snapshot + destroy routes exist ------------------------------
if grep -q "version-history.snapshot" "$ROUTES_FILE"; then
  echo "   [ok] Route name version-history.snapshot already present; not adding duplicate."
else
  echo "==> Appending snapshot + destroy routes to routes/web.php"
  cat >> "$ROUTES_FILE" << 'ROUTES'

/*
|--------------------------------------------------------------------------
| Version History snapshot / delete (UI-triggered)
|--------------------------------------------------------------------------
|
| These routes allow the Version History screen to:
|  - Create a new snapshot from the current state (code + DB) with a note.
|  - Delete an existing snapshot and all its artifacts.
*/
Route::post('/settings/version-history/snapshot', [VersionHistorySnapshotsController::class, 'snapshot'])
    ->name('version-history.snapshot');

Route::delete('/settings/version-history/{id}', [VersionHistorySnapshotsController::class, 'destroy'])
    ->name('version-history.destroy');
ROUTES
fi

# --- Write controller: VersionHistorySnapshotsController -----------------
cat > "$CTRL_FILE" << 'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Filesystem\Filesystem;
use Symfony\Component\Process\Process;

class VersionHistorySnapshotsController extends Controller
{
    /**
     * Create a new snapshot from the current state (code + DB),
     * by calling scripts/version_snapshot.sh "<NOTE>".
     */
    public function snapshot(Request $request)
    {
        $note = trim((string) $request->input('note', ''));

        if ($note === '') {
            return back()
                ->with('snapshot_error', 'Snapshot note is required.')
                ->withInput();
        }

        $scriptPath = base_path('scripts/version_snapshot.sh');

        if (!is_file($scriptPath) || !is_readable($scriptPath)) {
            return back()->with('snapshot_error', "Snapshot script not found or not readable at {$scriptPath}");
        }

        // Run: bash scripts/version_snapshot.sh "<note>"
        $process = new Process(['bash', $scriptPath, $note], base_path(), null, null, 600);

        try {
            $process->run();
        } catch (\Throwable $e) {
            return back()->with([
                'snapshot_error'  => 'Snapshot script threw an exception: ' . $e->getMessage(),
                'snapshot_output' => '',
            ]);
        }

        $output = $process->getOutput() . $process->getErrorOutput();
        $exitCode = $process->getExitCode();

        if ($exitCode !== 0) {
            return back()->with([
                'snapshot_error'  => "Snapshot script failed with exit code {$exitCode}.",
                'snapshot_output' => $output,
            ]);
        }

        // Success: redirect back to the Version History screen so the new snapshot shows up
        return redirect()
            ->route('settings.version-history.index')
            ->with('snapshot_status', 'Snapshot created successfully from current state.')
            ->with('snapshot_output', $output);
    }

    /**
     * Delete a snapshot by ID:
     *  - Remove directory backups/version_history/<ID> (if present)
     *  - Remove the line from storage/app/version_history/snapshots.log
     */
    public function destroy(string $id)
    {
        // Basic sanity check: only allow safe characters
        if (!preg_match('/^[A-Za-z0-9_\-]+$/', $id)) {
            return back()->with('snapshot_error', 'Invalid snapshot ID.');
        }

        $fs = new Filesystem();

        // 1) Delete the snapshot directory
        $snapshotDir = base_path('backups/version_history/' . $id);
        $dirDeleted = false;

        if ($fs->isDirectory($snapshotDir)) {
            $dirDeleted = $fs->deleteDirectory($snapshotDir);
        } elseif ($fs->exists($snapshotDir)) {
            // In case it is a file (e.g., tarball directly)
            $dirDeleted = $fs->delete($snapshotDir);
        }

        // 2) Remove line from snapshots.log
        $logPath = storage_path('app/version_history/snapshots.log');
        $logUpdated = false;

        if (is_file($logPath) && is_readable($logPath)) {
            $lines = file($logPath, FILE_IGNORE_NEW_LINES);
            if ($lines !== false) {
                $kept = [];
                $removed = false;

                foreach ($lines as $line) {
                    if (trim($line) === '') {
                        $kept[] = $line;
                        continue;
                    }

                    $parts = explode('|', $line);
                    $lineId = $parts[0] ?? null;

                    if ($lineId === $id) {
                        $removed = true;
                        continue;
                    }

                    $kept[] = $line;
                }

                $newContent = implode(PHP_EOL, $kept);
                if ($newContent !== '') {
                    $newContent .= PHP_EOL;
                }

                if (file_put_contents($logPath, $newContent) !== false) {
                    $logUpdated = true;
                }

                if (!$removed) {
                    // We did not actually find a line for this ID
                    $logUpdated = false;
                }
            }
        }

        $messages = [];

        if ($dirDeleted) {
            $messages[] = "Snapshot directory '{$id}' deleted.";
        } else {
            $messages[] = "Snapshot directory '{$id}' not found or could not be deleted.";
        }

        if ($logUpdated) {
            $messages[] = "Entry for snapshot '{$id}' removed from snapshots.log.";
        } else {
            $messages[] = "No matching entry for snapshot '{$id}' found in snapshots.log, or log not updated.";
        }

        return redirect()
            ->route('settings.version-history.index')
            ->with('snapshot_status', implode(' ', $messages));
    }
}
PHP

echo "==> Controller written: $CTRL_FILE"

# --- Overwrite the Version History view with note field + messages -------
cat > "$VIEW_FILE" << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Version history
        </h2>
    </x-slot>

    <div
        class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4"
        x-data="{ showRollback: false, rollbackId: null }"
    >
        <div class="bg-white rounded-lg shadow p-4">
            {{-- Rollback error / output, if any --}}
            @if (session('rollback_error'))
                <div class="mb-4 rounded-md bg-red-50 border border-red-200 px-3 py-2 text-xs text-red-700">
                    <div class="font-semibold mb-1">
                        Rollback error
                    </div>
                    <div class="mb-1">
                        {{ session('rollback_error') }}
                    </div>
                    @if (session('rollback_output'))
                        <div class="mt-1">
                            <div class="font-semibold mb-1">Rollback output</div>
                            <pre class="bg-red-900/5 text-[11px] text-red-800 rounded p-2 overflow-x-auto"><code>{{ session('rollback_output') }}</code></pre>
                        </div>
                    @endif
                </div>
            @endif

            {{-- Snapshot status / error / output --}}
            @if (session('snapshot_status'))
                <div class="mb-4 rounded-md bg-green-50 border border-green-200 px-3 py-2 text-xs text-green-700">
                    {{ session('snapshot_status') }}
                </div>
            @endif

            @if (session('snapshot_error'))
                <div class="mb-4 rounded-md bg-red-50 border border-red-200 px-3 py-2 text-xs text-red-700">
                    {{ session('snapshot_error') }}
                </div>
            @endif

            @if (session('snapshot_output'))
                <div class="mb-4">
                    <div class="font-semibold text-xs text-gray-700 mb-1">Snapshot script output</div>
                    <pre class="bg-gray-100 text-[11px] text-gray-800 rounded p-2 overflow-x-auto"><code>{{ session('snapshot_output') }}</code></pre>
                </div>
            @endif

            <p class="text-sm text-gray-600 mb-2">
                Each entry below corresponds to a snapshot created by
                <code class="font-mono text-xs bg-gray-100 px-1 py-0.5 rounded">
                    ./scripts/version_snapshot.sh
                </code>
                before running a change script or by the UI button below.
            </p>

            <p class="text-sm text-gray-600 mb-4">
                Snapshot artifacts are stored under
                <code class="font-mono text-xs bg-gray-100 px-1 py-0.5 rounded">
                    backups/version_history/&lt;SNAPSHOT_ID&gt;/
                </code>
                in your project root, and the textual ledger lives at
                <code class="font-mono text-xs bg-gray-100 px-1 py-0.5 rounded">
                    storage/app/version_history/snapshots.log
                </code>.
            </p>

            {{-- Global: create backup / snapshot from current state (with mandatory note) --}}
            <form action="{{ route('version-history.snapshot') }}" method="POST" class="mb-4">
                @csrf
                <div class="flex flex-wrap items-center gap-2">
                    <input
                        type="text"
                        name="note"
                        required
                        value="{{ old('note') }}"
                        placeholder="Short note for this backup (required)"
                        class="flex-1 min-w-[200px] rounded-md border-gray-300 text-xs shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                    >
                    <button
                        type="submit"
                        class="inline-flex items-center px-4 py-2 border border-transparent text-xs font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                    >
                        Create backup from current state
                    </button>
                </div>
            </form>

            @if (empty($snapshots))
                <p class="text-sm text-gray-500">
                    No snapshots have been recorded yet.
                </p>
            @else
                <div class="overflow-x-auto">
                    <table class="min-w-full text-sm">
                        <thead>
                            <tr class="bg-gray-50 text-left text-xs font-semibold uppercase tracking-wide text-gray-600">
                                <th class="px-3 py-2">ID</th>
                                <th class="px-3 py-2 whitespace-nowrap">Created at (UTC)</th>
                                <th class="px-3 py-2">Type</th>
                                <th class="px-3 py-2">Note</th>
                                <th class="px-3 py-2 whitespace-nowrap">DB dump</th>
                                <th class="px-3 py-2 whitespace-nowrap">Code archive</th>
                                <th class="px-3 py-2 whitespace-nowrap">Git commit</th>
                                <th class="px-3 py-2 whitespace-nowrap">Rollback</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            @foreach($snapshots as $snapshot)
                                <tr>
                                    <td class="px-3 py-2 font-mono text-xs align-top">
                                        {{ $snapshot['id'] ?? '' }}
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700 whitespace-nowrap align-top">
                                        {{ $snapshot['created_at'] ?? '—' }}
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700 whitespace-nowrap align-top">
                                        <span class="inline-flex items-center rounded-full px-2 py-0.5 text-[11px]
                                                     @if(($snapshot['type'] ?? 'manual') === 'auto')
                                                         bg-blue-50 text-blue-700 border border-blue-200
                                                     @else
                                                         bg-gray-50 text-gray-700 border border-gray-200
                                                     @endif">
                                            {{ $snapshot['type'] ?? 'manual' }}
                                        </span>
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700 align-top">
                                        {{ $snapshot['note'] ?? '' }}
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700 align-top">
                                        <code class="font-mono">
                                            {{ $snapshot['db_dump'] ?? '—' }}
                                        </code>
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700 align-top">
                                        <code class="font-mono">
                                            {{ $snapshot['code_archive'] ?? '—' }}
                                        </code>
                                    </td>
                                    <td class="px-3 py-2 text-xs font-mono text-gray-700 whitespace-nowrap align-top">
                                        {{ \Illuminate\Support\Str::limit($snapshot['git_commit'] ?? '', 10, '') }}
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700 align-top space-y-1">
                                        @if (!empty($snapshot['id']))
                                            <div>
                                                <code class="font-mono bg-gray-100 px-1 py-0.5 rounded break-all">
                                                    ./scripts/version_rollback.sh {{ $snapshot['id'] }}
                                                </code>
                                            </div>
                                            <div class="space-y-1">
                                                <button
                                                    type="button"
                                                    class="inline-flex items-center rounded-md border border-gray-300 px-2 py-1 text-[11px] text-gray-700 bg-white hover:bg-gray-50"
                                                    @click.prevent="showRollback = true; rollbackId = '{{ $snapshot['id'] }}'"
                                                >
                                                    {{ __('Show rollback command') }}
                                                </button>

                                                <form
                                                    method="POST"
                                                    action="{{ route('settings.version-history.rollback') }}"
                                                    class="inline"
                                                    onsubmit="return confirm('Are you sure you want to rollback to this snapshot? This will restore both code and database.');"
                                                >
                                                    @csrf
                                                    <input type="hidden" name="snapshot_id" value="{{ $snapshot['id'] }}">
                                                    <button
                                                        type="submit"
                                                        class="inline-flex items-center rounded-md border border-red-300 px-2 py-1 text-[11px] text-red-700 bg-white hover:bg-red-50"
                                                    >
                                                        {{ __('Rollback now') }}
                                                    </button>
                                                </form>

                                                {{-- Delete backup + all its files --}}
                                                <form
                                                    action="{{ route('version-history.destroy', $snapshot['id']) }}"
                                                    method="POST"
                                                    class="inline"
                                                    onsubmit="return confirm('Are you sure you want to delete this backup and all its files?');"
                                                >
                                                    @csrf
                                                    @method('DELETE')
                                                    <button
                                                        type="submit"
                                                        class="inline-flex items-center rounded-md border border-gray-300 px-2 py-1 text-[11px] text-gray-700 bg-white hover:bg-gray-50"
                                                    >
                                                        {{ __('Delete backup') }}
                                                    </button>
                                                </form>
                                            </div>
                                        @else
                                            —
                                        @endif
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>

                <p class="mt-4 text-xs text-gray-500 space-y-1">
                    <span class="block">
                        Create manual snapshot from the terminal:
                        <code class="font-mono bg-gray-100 px-1 py-0.5 rounded">
                            ./scripts/version_snapshot.sh "Manual snapshot before tweaking IMAP settings"
                        </code>
                    </span>
                    <span class="block">
                        Rollback to a specific snapshot:
                        <code class="font-mono bg-gray-100 px-1 py-0.5 rounded">
                            ./scripts/version_rollback.sh SNAPSHOT_ID
                        </code>
                    </span>
                </p>
            @endif
        </div>

        {{-- Tiny helper modal: shows rollback command, does NOT execute anything --}}
        <div
            x-cloak
            x-show="showRollback"
            class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        >
            <div class="bg-white rounded-lg shadow-xl max-w-lg w-full mx-4 p-4">
                <h3 class="text-sm font-semibold text-gray-900 mb-2">
                    Rollback snapshot
                </h3>

                <p class="text-xs text-gray-600 mb-3">
                    This does <span class="font-semibold">not</span> run automatically.
                    Copy and paste the command below into your terminal on the
                    <code class="font-mono bg-gray-100 px-1 py-0.5 rounded">~/sms-procurement-platform</code>
                    host, review it, and press Enter to perform the rollback
                    — or click <span class="font-semibold">Rollback now</span> in the table row to run it from the UI.
                </p>

                <pre class="bg-gray-100 text-[11px] p-2 rounded overflow-x-auto mb-3">
<code class="font-mono">cd ~/sms-procurement-platform
./scripts/version_rollback.sh <span x-text="rollbackId"></span></code>
                </pre>

                <p class="text-[11px] text-gray-500 mb-4">
                    WARNING: This will restore both the application code and the Postgres database
                    to the state captured in the selected snapshot. Any newer data or code changes
                    may be lost.
                </p>

                <div class="mt-2 flex justify-end gap-2">
                    <button
                        type="button"
                        class="px-3 py-1.5 text-xs rounded-md border border-gray-300 text-gray-700 bg-white hover:bg-gray-50"
                        @click="showRollback = false; rollbackId = null"
                    >
                        {{ __('Close') }}
                    </button>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
BLADE

echo "==> Updated controller + view for Version History snapshot actions."
echo "==> Backup stored at: $BACKUP_DIR"
echo "==> To rollback, you can restore individual files, e.g.:"
echo "cp \"$BACKUP_DIR/version-history.blade.php\" \"$VIEW_FILE\""
echo "cp \"$BACKUP_DIR/VersionHistorySnapshotsController.php\" \"$CTRL_FILE\""
echo "cp \"$BACKUP_DIR/web.php\" \"$ROUTES_FILE\""
