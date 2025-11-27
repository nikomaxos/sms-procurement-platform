<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Symfony\Component\Process\Process;

class VersionHistoryController extends Controller
{
    public function __construct()
    {
        $this->middleware('auth');
    }

    /**
     * Show the snapshots timeline.
     *
     * Ledger format (one line per snapshot, pipe-separated):
     *   id|created_at|note|type|db_dump|code_archive|git_commit
     */
    public function index()
    {
        $ledgerPath = storage_path('app/version_history/snapshots.log');
        $snapshots = [];

        if (is_file($ledgerPath)) {
            $lines = file($ledgerPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];

            foreach ($lines as $line) {
                $parts = array_map('trim', explode('|', $line));

                // Pad to 7 elements: id, created_at, note, type, db_dump, code_archive, git_commit
                $parts = array_pad($parts, 7, null);

                [$id, $createdAt, $note, $type, $dbDump, $codeArchive, $gitCommit] = $parts;

                if (!$id || !$createdAt) {
                    continue;
                }

                $snapshots[] = [
                    'id'           => $id,
                    'created_at'   => $createdAt,
                    'note'         => $note,
                    'type'         => $type ?? 'manual',
                    'db_dump'      => $dbDump,
                    'code_archive' => $codeArchive,
                    'git_commit'   => $gitCommit,
                ];
            }

            // Newest first by created_at text
            usort($snapshots, static function (array $a, array $b) {
                return strcmp($b['created_at'] ?? '', $a['created_at'] ?? '');
            });
        }

        return $this->renderView(compact('snapshots'));
    }

    /**
     * Trigger rollback for a given snapshot ID by calling scripts/version_rollback.sh.
     *
     * On success: redirect to dashboard.
     * On failure: redirect back to Version history with error + captured output.
     */
    public function rollback(Request $request)
    {
        $snapshotId = trim((string) $request->input('snapshot_id', ''));

        // Basic validation / sanitization to avoid command injection
        if ($snapshotId === '' || !preg_match('/^[A-Za-z0-9._-]+$/', $snapshotId)) {
            return redirect()
                ->route('settings.version-history.index')
                ->with('rollback_error', 'Invalid snapshot ID.')
                ->with('rollback_output', '');
        }

        $command = ['bash', 'scripts/version_rollback.sh', $snapshotId];

        // Set NON_INTERACTIVE=1 so the script skips any interactive prompt.
        $env = array_merge($_SERVER, ['NON_INTERACTIVE' => '1']);

        $process = new Process($command, base_path(), $env, null, 3600);

        try {
            $process->run();
        } catch (\Throwable $e) {
            $output = $process->getOutput() . $process->getErrorOutput();
            $output .= "\n[Exception] " . $e->getMessage();

            return redirect()
                ->route('settings.version-history.index')
                ->with('rollback_error', 'Rollback process threw an exception.')
                ->with('rollback_output', $output);
        }

        $exitCode = $process->getExitCode();
        $output   = $process->getOutput() . $process->getErrorOutput();

        if ($exitCode !== 0) {
            return redirect()
                ->route('settings.version-history.index')
                ->with('rollback_error', "Rollback script exited with code {$exitCode}.")
                ->with('rollback_output', $output);
        }

        // Success → go to dashboard
        return redirect()
            ->route('dashboard')
            ->with('status', "Rollback to snapshot {$snapshotId} completed successfully.");
    }

    /**
     * Try a few possible view names so we don't 500 if the blade filename differs.
     */
    protected function renderView(array $data = [])
    {
        $candidates = [
            'settings.version-history',   // resources/views/settings/version-history.blade.php
            'settings.version_history',   // resources/views/settings/version_history.blade.php
            'settings.index',             // fallback if you reused the old settings index
        ];

        foreach ($candidates as $view) {
            if (view()->exists($view)) {
                return view($view, $data);
            }
        }

        abort(500, 'Version history view not found under resources/views/settings.');
    }
}
