#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

echo "==> Creating version history dirs"
mkdir -p "${ROOT}/storage/app/version_history" "${ROOT}/storage/app/db_dumps" "${ROOT}/scripts"

############################################
# 1) Controller: app/Http/Controllers/VersionHistoryController.php
############################################
cat > "${ROOT}/app/Http/Controllers/VersionHistoryController.php" << 'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class VersionHistoryController extends Controller
{
    public function index(Request $request)
    {
        $files = Storage::files('version_history');

        $snapshots = [];

        foreach ($files as $file) {
            if (!str_ends_with($file, '.json')) {
                continue;
            }

            try {
                $raw  = Storage::get($file);
                $data = json_decode($raw, true);
            } catch (\Throwable $e) {
                continue;
            }

            if (!is_array($data)) {
                continue;
            }

            $data['id']          = $data['id'] ?? basename($file, '.json');
            $data['created_at']  = $data['created_at'] ?? null;
            $data['label']       = $data['label'] ?? '';
            $data['git_commit']  = $data['git_commit'] ?? null;
            $data['db_dump_path'] = $data['db_dump_path'] ?? null;

            $snapshots[] = $data;
        }

        usort($snapshots, function (array $a, array $b) {
            return strcmp($b['created_at'] ?? '', $a['created_at'] ?? '');
        });

        return view('settings.version_history', [
            'snapshots' => $snapshots,
        ]);
    }
}
PHP

############################################
# 2) Blade view: resources/views/settings/version_history.blade.php
############################################
mkdir -p "${ROOT}/resources/views/settings"

cat > "${ROOT}/resources/views/settings/version_history.blade.php" << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Version history
        </h2>
    </x-slot>

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
        <div class="bg-white p-4 rounded-lg shadow">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">How snapshots work</h3>
            <p class="text-sm text-gray-700 mb-2">
                Snapshots are created on the host using shell scripts. Each snapshot includes:
            </p>
            <ul class="list-disc text-sm text-gray-700 pl-5 space-y-1 mb-3">
                <li>Compressed PostgreSQL dump (DB state)</li>
                <li>Metadata JSON (label, timestamp, git commit, containers)</li>
            </ul>
            <p class="text-sm text-gray-700 mb-1">
                Create a snapshot from the host:
            </p>
            <pre class="bg-gray-900 text-gray-100 text-xs rounded-md p-3 overflow-x-auto mb-2">
cd ~/sms-procurement-platform
./scripts/version_snapshot.sh "Before changing networks controller"
            </pre>
            <p class="text-sm text-gray-700">
                Rollback to a snapshot (from host):
            </p>
            <pre class="bg-gray-900 text-gray-100 text-xs rounded-md p-3 overflow-x-auto">
cd ~/sms-procurement-platform
./scripts/version_rollback.sh &lt;SNAPSHOT_ID&gt;
            </pre>
            <p class="text-xs text-gray-500 mt-2">
                Rollback will restore the PostgreSQL database to that snapshot. Code rollback is done via git using the commit shown below.
            </p>
        </div>

        <div class="bg-white p-4 rounded-lg shadow">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">
                Timeline
            </h3>

            @if (empty($snapshots))
                <p class="text-sm text-gray-500">
                    No snapshots found yet. Create your first one from the host using
                    <code class="bg-gray-100 px-1 rounded text-xs">./scripts/version_snapshot.sh "Label"</code>.
                </p>
            @else
                <div class="space-y-4">
                    @foreach ($snapshots as $snap)
                        <div class="border-l-2 border-indigo-400 pl-4 py-2">
                            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                                <div>
                                    <div class="text-sm font-semibold text-gray-900">
                                        {{ $snap['label'] ?: 'Snapshot ' . $snap['id'] }}
                                    </div>
                                    <div class="text-xs text-gray-500">
                                        ID: <span class="font-mono">{{ $snap['id'] }}</span>
                                        @if (!empty($snap['created_at']))
                                            · {{ $snap['created_at'] }}
                                        @endif
                                    </div>
                                    @if (!empty($snap['git_commit']))
                                        <div class="text-xs text-gray-500 mt-1">
                                            Git commit:
                                            <span class="font-mono">
                                                {{ substr($snap['git_commit'], 0, 12) }}
                                            </span>
                                        </div>
                                    @endif
                                    @if (!empty($snap['db_dump_path']))
                                        <div class="text-xs text-gray-500 mt-1">
                                            DB dump:
                                            <span class="font-mono">{{ $snap['db_dump_path'] }}</span>
                                        </div>
                                    @endif
                                </div>
                                <div class="flex flex-col items-start sm:items-end gap-1">
                                    <div class="text-xs text-gray-500">
                                        Rollback command:
                                    </div>
                                    <pre class="bg-gray-900 text-gray-100 text-xs rounded-md px-2 py-1 font-mono">
./scripts/version_rollback.sh {{ $snap['id'] }}</pre>
                                </div>
                            </div>
                        </div>
                    @endforeach
                </div>
            @endif
        </div>
    </div>
</x-app-layout>
BLADE

############################################
# 3) Add route (if not already present)
############################################
if ! grep -q "settings.version-history.index" "${ROOT}/routes/web.php"; then
  echo "==> Appending route to routes/web.php"
  cat >> "${ROOT}/routes/web.php" << 'PHP'

Route::middleware(['web', 'auth'])->group(function () {
    Route::get('/settings/version-history', [\App\Http\Controllers\VersionHistoryController::class, 'index'])
        ->name('settings.version-history.index');
});
PHP
else
  echo "==> Route for settings.version-history.index already exists, skipping."
fi

############################################
# 4) Snapshot script (host) - scripts/version_snapshot.sh
############################################
cat > "${ROOT}/scripts/version_snapshot.sh" << 'SH'
#!/usr/bin/env bash
set -euo pipefail

# [IMPORTANT]
# Adjust these DB settings to match your docker-compose / env:
DB_CONTAINER="sms-platform-postgres"   # container name for postgres
DB_USER="postgres"                     # database user
DB_NAME="sms_platform"                 # database name

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LABEL="${1:-Manual snapshot}"
SNAP_ID="$(date +%Y%m%d_%H%M%S)"
TS_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

DUMPS_DIR="${ROOT}/storage/app/db_dumps"
META_DIR="${ROOT}/storage/app/version_history"

mkdir -p "${DUMPS_DIR}" "${META_DIR}"

DUMP_FILE="${DUMPS_DIR}/${SNAP_ID}.sql.gz"

echo "==> Creating DB dump via docker compose (container: ${DB_CONTAINER})"
docker compose exec -T "${DB_CONTAINER}" pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip > "${DUMP_FILE}"

GIT_COMMIT="$(cd "${ROOT}" && git rev-parse HEAD 2>/dev/null || echo "")"

# Escape quotes in label for JSON
SAFE_LABEL="$(printf '%s' "${LABEL}" | sed 's/"/\\"/g')"

META_FILE="${META_DIR}/${SNAP_ID}.json"

cat > "${META_FILE}" <<EOF
{
  "id": "${SNAP_ID}",
  "label": "${SAFE_LABEL}",
  "created_at": "${TS_ISO}",
  "git_commit": "${GIT_COMMIT}",
  "db_dump_path": "storage/app/db_dumps/${SNAP_ID}.sql.gz",
  "db_container": "${DB_CONTAINER}",
  "db_name": "${DB_NAME}",
  "db_user": "${DB_USER}",
  "containers": [
    "sms-platform-app",
    "sms-platform-web",
    "sms-platform-postgres"
  ]
}
