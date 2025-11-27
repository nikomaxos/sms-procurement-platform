#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TIMESTAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR="$ROOT/backup_add_version_history_snapshot_buttons_${TIMESTAMP}"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/add_version_history_snapshot_buttons_${TIMESTAMP}.log"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# Log everything to file + stdout
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Working dir: $ROOT"
echo "==> Backup dir:  $BACKUP_DIR"
echo "==> Log file:    $LOG_FILE"

backup_file() {
  local src="$1"
  if [ -f "$src" ]; then
    local base
    base="$(basename "$src")"
    cp "$src" "$BACKUP_DIR/$base"
    echo "   [backup] $src -> $BACKUP_DIR/$base"
  else
    echo "   [skip backup] $src (not found)"
  fi
}

ROUTES_FILE="$ROOT/routes/web.php"
SNAPSHOT_CTRL_FILE="$ROOT/app/Http/Controllers/VersionHistorySnapshotsController.php"
VIEW_EXAMPLE_FILE="$ROOT/resources/views/version-history/_snapshot_buttons_example.blade.php"

echo "==> Backing up key files (if present)..."
backup_file "$ROUTES_FILE"
backup_file "$SNAPSHOT_CTRL_FILE"
backup_file "$VIEW_EXAMPLE_FILE"

echo
echo "==> Ensuring routes import VersionHistorySnapshotsController..."

if ! grep -q 'use App\\Http\\Controllers\\VersionHistorySnapshotsController;' "$ROUTES_FILE"; then
  # Insert after use Illuminate\Support\Facades\Route;
  perl -0pi -e 's@(use Illuminate\\\Support\\\Facades\\\Route;[\r\n]+)@$1use App\\\Http\\\Controllers\\\VersionHistorySnapshotsController;\n@' "$ROUTES_FILE" \
    || echo "   [warn] Could not auto-insert use statement; please add it manually."
  echo "   [ok] use App\\Http\\Controllers\\VersionHistorySnapshotsController; ensured"
else
  echo "   [ok] use statement already present"
fi

echo
echo "==> Adding snapshot/destroy routes (if missing)..."

if grep -q "version-history.snapshot" "$ROUTES_FILE"; then
  echo "   [ok] Route name version-history.snapshot already exists, not adding again."
else
  cat >> "$ROUTES_FILE" << 'PHP'

/*
|--------------------------------------------------------------------------
| Version History snapshot routes (UI backup/delete)
|--------------------------------------------------------------------------
*/
Route::middleware(['auth'])->group(function () {
    Route::post('/version-history/snapshot', [VersionHistorySnapshotsController::class, 'snapshot'])
        ->name('version-history.snapshot');

    Route::delete('/version-history/{snapshot}', [VersionHistorySnapshotsController::class, 'destroy'])
        ->name('version-history.destroy');
});
PHP
  echo "   [ok] Added snapshot + destroy routes at bottom of routes/web.php"
fi

echo
echo "==> Writing controller: app/Http/Controllers/VersionHistorySnapshotsController.php"

mkdir -p "$(dirname "$SNAPSHOT_CTRL_FILE")"

cat > "$SNAPSHOT_CTRL_FILE" << 'PHP'
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
PHP

echo "   [ok] Controller written"

echo
echo "==> Writing Blade partial example: resources/views/version-history/_snapshot_buttons_example.blade.php"

mkdir -p "$(dirname "$VIEW_EXAMPLE_FILE")"

cat > "$VIEW_EXAMPLE_FILE" << 'BLADE'
{{-- 
  Version history snapshot UI helpers

  How to use:

  1) GLOBAL "Create backup" button:
     Place this form somewhere near the top of your Version History page.

  2) PER-ROW "Delete backup" button:
     Use inside your @foreach($snapshots as $snapshot) loop, replacing
     $snapshot['name'] with the actual identifier you use for the snapshot dir.
--}}

{{-- 1) Global create-backup button --}}
<form action="{{ route('version-history.snapshot') }}" method="POST" class="mb-4">
  @csrf
  <button
    type="submit"
    class="inline-flex items-center px-4 py-2 rounded-md bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
  >
    Create backup from current state
  </button>
</form>

{{-- 2) Per-record delete button example (inside your loop) --}}
{{--
@foreach($snapshots as $snapshot)
  <tr>
    <!-- your other columns here -->

    <td class="text-right space-x-2">
      <form
        action="{{ route('version-history.destroy', $snapshot['name']) }}"
        method="POST"
        class="inline-block"
        onsubmit="return confirm('Delete backup {{ $snapshot['name'] }} and all its files? This cannot be undone.');"
      >
        @csrf
        @method('DELETE')
        <button
          type="submit"
          class="inline-flex items-center px-3 py-1 rounded-md bg-red-600 text-white text-xs font-semibold hover:bg-red-700"
        >
          Delete
        </button>
      </form>
    </td>
  </tr>
@endforeach
--}}

BLADE

echo "   [ok] Partial example written"

echo
echo "==> Rollback info"

echo "Backups are stored in: $BACKUP_DIR" | tee -a "$LOG_FILE"
echo "To rollback the files touched by this script, you can run the following (if backups exist):" | tee -a "$LOG_FILE"

{
  echo "# Example rollback commands (only if these files exist in your backup dir):"
  [ -f "$BACKUP_DIR/web.php" ] && echo "cp \"$BACKUP_DIR/web.php\" \"$ROUTES_FILE\""
  [ -f "$BACKUP_DIR/VersionHistorySnapshotsController.php" ] && echo "cp \"$BACKUP_DIR/VersionHistorySnapshotsController.php\" \"$SNAPSHOT_CTRL_FILE\""
  [ -f "$BACKUP_DIR/_snapshot_buttons_example.blade.php" ] && echo "cp \"$BACKUP_DIR/_snapshot_buttons_example.blade.php\" \"$VIEW_EXAMPLE_FILE\""
} | tee -a "$LOG_FILE"

echo
echo "==> Done. Now:"
echo "  1) Open routes/web.php and verify the new snapshot routes at the bottom."
echo "  2) Open resources/views/version-history/index.blade.php and include or copy from:"
echo "       @include('version-history._snapshot_buttons_example')"
echo "     placing the global button and per-row delete button where you want them."
echo "  3) Visit your Version History page and test:"
echo "       - Create backup button"
echo "       - Delete backup button (per snapshot)"
