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
