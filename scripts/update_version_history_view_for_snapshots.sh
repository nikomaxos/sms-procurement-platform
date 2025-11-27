#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TIMESTAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR="$ROOT/backup_update_version_history_view_for_snapshots_${TIMESTAMP}"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/update_version_history_view_for_snapshots_${TIMESTAMP}.log"

VIEW_FILE="$ROOT/resources/views/settings/version-history.blade.php"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# Log to file + stdout
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Working dir: $ROOT"
echo "==> Backup dir:  $BACKUP_DIR"
echo "==> Log file:    $LOG_FILE"
echo "==> View file:   $VIEW_FILE"

if [ ! -f "$VIEW_FILE" ]; then
  echo "   [ERROR] View file not found: $VIEW_FILE"
  exit 1
fi

# Backup existing view
cp "$VIEW_FILE" "$BACKUP_DIR/version-history.blade.php"
echo "   [backup] $VIEW_FILE -> $BACKUP_DIR/version-history.blade.php"

# Overwrite view with updated version (create + delete buttons)
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

            <p class="text-sm text-gray-600 mb-4">
                Each entry below corresponds to a snapshot created by
                <code class="font-mono text-xs bg-gray-100 px-1 py-0.5 rounded">
                    ./scripts/version_snapshot.sh
                </code>
                before running a change script.
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

            {{-- Global: create backup / snapshot from current state --}}
            <form action="{{ route('version-history.snapshot') }}" method="POST" class="mb-4">
                @csrf
                <button
                    type="submit"
                    class="inline-flex items-center px-4 py-2 border border-transparent text-xs font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                >
                    Create backup from current state
                </button>
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

                                                {{-- New: delete backup + all its files --}}
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
                        Create manual snapshot (before you change something manually):
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

echo "==> Updated version history view with snapshot create/delete buttons."
echo "==> Backup stored at: $BACKUP_DIR"
echo "==> To rollback this view only, run:"
echo "cp \"$BACKUP_DIR/version-history.blade.php\" \"$VIEW_FILE\""
