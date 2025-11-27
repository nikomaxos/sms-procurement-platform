<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Version history
        </h2>
    </x-slot>

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
        <div class="bg-white rounded-lg shadow p-4">
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
                                <th class="px-3 py-2 whitespace-nowrap">Rollback command</th>
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
                                    <td class="px-3 py-2 text-xs text-gray-700 align-top">
                                        @if (!empty($snapshot['id']))
                                            <code class="font-mono bg-gray-100 px-1 py-0.5 rounded break-all">
                                                ./scripts/version_rollback.sh {{ $snapshot['id'] }}
                                            </code>
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
    </div>
</x-app-layout>
