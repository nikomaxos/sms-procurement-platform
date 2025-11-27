<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\File;
use Symfony\Component\Process\Process;
use Symfony\Component\Process\Exception\ProcessFailedException;

class VersionHistorySnapshotsController extends Controller
{
    /**
     * Root folder where snapshots are stored.
     *
     * Layout:
     *   storage/app/versioning/<timestamp>_manual/
     *     - code.tar.gz
     *     - meta.json
     */
    protected string $snapshotsRoot;

    public function __construct()
    {
        $this->snapshotsRoot = storage_path('app/versioning');
    }

    /**
     * Create a new snapshot (backup) of the current project state.
     *
     * Tarball excludes .git, vendor, node_modules, Laravel caches/logs, and
     * the snapshots folder itself.
     */
    public function snapshot(Request $request)
    {
        File::ensureDirectoryExists($this->snapshotsRoot);

        $timestamp    = now()->format('Y-m-d_H-i-s');
        $label        = 'manual';
        $snapshotName = $timestamp . '_' . $label;

        $snapshotDir  = $this->snapshotsRoot . DIRECTORY_SEPARATOR . $snapshotName;
        File::ensureDirectoryExists($snapshotDir);

        $archivePath  = $snapshotDir . DIRECTORY_SEPARATOR . 'code.tar.gz';

        $cmd = [
            'tar',
            '-czf',
            $archivePath,
            '--exclude=.git',
            '--exclude=vendor',
            '--exclude=node_modules',
            '--exclude=storage/framework/cache',
            '--exclude=storage/framework/sessions',
            '--exclude=storage/framework/views',
            '--exclude=storage/logs',
            '--exclude=storage/app/versioning',
            '.',
        ];

        $process = new Process($cmd, base_path());
        $process->setTimeout(600); // 10 minutes
        $process->run();

        if (! $process->isSuccessful()) {
            // Clean up incomplete snapshot directory
            File::deleteDirectory($snapshotDir);
            throw new ProcessFailedException($process);
        }

        $meta = [
            'name'       => $snapshotName,
            'created_at' => now()->toIso8601String(),
            'user'       => optional($request->user())->email,
            'note'       => 'Manual snapshot from web UI',
        ];

        file_put_contents(
            $snapshotDir . DIRECTORY_SEPARATOR . 'meta.json',
            json_encode($meta, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
        );

        return redirect()->back()->with('status', "Snapshot {$snapshotName} created.");
    }

    /**
     * Delete a snapshot directory and all its files.
     */
    public function destroy(string $snapshot)
    {
        $base = realpath($this->snapshotsRoot);
        if ($base === false) {
            abort(500, 'Snapshots root not found.');
        }

        $target = realpath($this->snapshotsRoot . DIRECTORY_SEPARATOR . $snapshot);
        if ($target === false || strpos($target, $base) !== 0) {
            abort(404, 'Snapshot not found.');
        }

        File::deleteDirectory($target);

        return redirect()->back()->with('status', "Snapshot {$snapshot} deleted.");
    }
}
