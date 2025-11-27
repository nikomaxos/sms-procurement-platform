#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TS="$(date +%F_%H-%M-%S)"
VIEW_FILE="$ROOT/resources/views/settings/version-history.blade.php"
BACKUP_DIR="$ROOT/backup_fix_version_history_view_crash_${TS}"

mkdir -p "$BACKUP_DIR" "$ROOT/logs"

if [ -f "$VIEW_FILE" ]; then
  cp "$VIEW_FILE" "$BACKUP_DIR/version-history.blade.php"
  echo "==> Backup: $VIEW_FILE -> $BACKUP_DIR/version-history.blade.php"
else
  echo "==> WARNING: $VIEW_FILE did not exist (creating fresh)."
fi

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
        <div class="bg-white rounded-lg shadow p-4 space-y-4">

            {{-- Snapshot success / error --}}
            @if (session('snapshot_success'))
                <div class="mb-2 rounded-md bg-green-50 border border-green-200 px-3 py-2 text-xs text-green-800">
                    <div class="font-semibold mb-1">
                        Snapshot created successfully from current state.
                    </div>
                    @if (session('snapshot_message'))
                        <div class="mb-1">
                            {{ session('snapshot_message') }}
                        </div>
                    @endif
                    @if (session('snapshot_output'))
                        <div class="mt-1">
                            <div class="font-semibold mb-1">Snapshot script output</div>
                            <pre class="bg-green-900/5 text-[11px] text-green-800 rounded p-2 overflow-x-auto"><code>{{ session('snapshot_output') }}</code></pre>
                        </div>
                    @endif
                </div>
            @elseif (session('snapshot_error'))
                <div class="mb-2 rounded-md bg-red-50 border border-red-200 px-3 py-2 text-xs text-red-700">
                    <div class="font-semibold mb-1">
                        Snapshot script failed.
                    </div>
                    <div class="mb-1">
                        {{ session('snapshot_error') }}
                    </div>
                    @if (session('snapshot_output'))
                        <div class="mt-1">
                            <div class="font-semibold mb-1">Snapshot script output</div>
                            <pre class="bg-red-900/5 text-[11px] text-red-800 rounded p-2 overflow-x-auto"><code>{{ session('snapshot_output') }}</code></pre>
                        </div>
                    @endif
                </div>
            @endif

            {{-- Rollback error / output --}}
            @if (session('rollback_error'))
                <div class="mb-2 rounded-md bg-red-50 border border-red-200 px-3 py-2 text-xs text-red-700">
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

            <p class="text-sm text-gray-600">
                Each entry below corresponds to a snapshot created by
                <code class="font-mono text-xs bg-gray-100 px-1 py-0.5 rounded">
                    ./scripts/version_snapshot.sh
                </code>
                either automatically before a change script, or manually from this page.
            </p>

            <p class="text-sm text-gray-600">
                Snapshot artifacts are stored under
                <code class="font-mono text-xs bg-gray-100 px-1 py-0.5 rounded">
                    backups/version_history/&lt;SNAPSHOT_ID&gt;/
                </code>
                in your project root, and the textual ledger lives at
                <code class="font-mono text-xs bg-gray-100 px-1 py-0.5 rounded">
                    storage/app/version_history/snapshots.log
                </code>.
            </p>

            {{-- Create snapshot from current state --}}
            <div class="border border-gray-200 rounded-md p-3 bg-gray-50/60 mb-4">
                <form
                    method="POST"
                    action="{{ route('settings.version-history.snapshot') }}"
                    class="flex flex-col md:flex-row md:items-end gap-2"
                >
                    @csrf
                    <div class="flex-1">
                        <label for="snapshot-note" class="block text-xs font-semibold text-gray-700 mb-1">
                            Snapshot note <span class="text-red-500">*</span>
                        </label>
                        <input
                            id="snapshot-note"
                            name="note"
                            type="text"
                            required
                            maxlength="200"
                            value="{{ old('note') }}"
                            class="block w-full rounded-md border-gray-300 shadow-sm text-xs focus:border-indigo-500 focus:ring-indigo-500"
                            placeholder="e.g. Before IMAP settings refactor"
                        >
                        <p class="mt-1 text-[11px] text-gray-500">
                            Short description of why you are taking this snapshot.
                            This note will be shown in the table below.
                        </p>
                    </div>
                    <div class="flex-shrink-0">
                        <button
                            type="submit"
                            class="inline-flex items-center rounded-md border border-indigo-600 bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-indigo-700"
                        >
                            Create snapshot from current state
                        </button>
                    </div>
                </form>
            </div>

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
                                <th class="px-3 py-2 whitespace-nowrap">Actions</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            @foreach($snapshots as $snapshot)
                                @php
                                    $rawType = $snapshot['type'] ?? null;
                                    $rawNote = $snapshot['note'] ?? null;

                                    // Heuristic to fix older rows where "type" and "note" ended up swapped.
                                    if (in_array($rawNote, ['auto', 'manual'], true)) {
                                        $type = $rawNote;
                                        $note = $rawType ?? '';
                                    } else {
                                        $type = $rawType ?? 'manual';
                                        $note = $rawNote ?? '';
                                    }
                                @endphp
                                <tr>
                                    <td class="px-3 py-2 font-mono text-xs align-top">
                                        {{ $snapshot['id'] ?? '' }}
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700 whitespace-nowrap align-top">
                                        {{ $snapshot['created_at'] ?? '—' }}
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700 whitespace-nowrap align-top">
                                        <span class="inline-flex items-center rounded-full px-2 py-0.5 text-[11px]
                                                     @if(($type ?? 'manual') === 'auto')
                                                         bg-blue-50 text-blue-700 border border-blue-200
                                                     @else
                                                         bg-gray-50 text-gray-700 border border-gray-200
                                                     @endif">
                                            {{ $type ?? 'manual' }}
                                        </span>
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700 align-top">
                                        {{ $note }}
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
                                                {{-- Show rollback command modal --}}
                                                <button
                                                    type="button"
                                                    class="inline-flex items-center rounded-md border border-gray-300 px-2 py-1 text-[11px] text-gray-700 bg-white hover:bg-gray-50"
                                                    @click.prevent="showRollback = true; rollbackId = '{{ $snapshot['id'] }}'"
                                                >
                                                    {{ __('Show rollback command') }}
                                                </button>

                                                {{-- Rollback now --}}
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

                                                {{-- Delete backup --}}
                                                <form
                                                    method="POST"
                                                    action="{{ route('settings.version-history.destroy', $snapshot['id']) }}"
                                                    class="inline"
                                                    onsubmit="return confirm('Are you sure you want to delete this snapshot and all its files? This cannot be undone.');"
                                                >
                                                    @csrf
                                                    @method('DELETE')
                                                    <button
                                                        type="submit"
                                                        class="inline-flex items-center rounded-md border border-gray-300 px-2 py-1 text-[11px] text-gray-600 bg-white hover:bg-gray-50"
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

        {{-- Helper modal: shows rollback command, does NOT execute anything --}}
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

echo "==> New view written to: $VIEW_FILE"
echo "==> Now clear compiled views inside the app container..."

# Clear compiled Blade views inside the app container
if command -v docker >/dev/null 2>&1; then
  docker compose exec app php artisan view:clear || true
fi

echo "==> Done."
