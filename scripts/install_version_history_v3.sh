#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Using project root: ${ROOT}"

VH_DIR="${ROOT}/storage/app/version_history"
DB_DIR="${ROOT}/storage/app/db_dumps"

echo "==> Ensuring snapshot dirs exist"
mkdir -p "${VH_DIR}" "${DB_DIR}"

############################################
# 1) VersionHistoryController
############################################
echo "==> Writing app/Http/Controllers/VersionHistoryController.php"
mkdir -p "${ROOT}/app/Http/Controllers"

cat > "${ROOT}/app/Http/Controllers/VersionHistoryController.php" << 'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class VersionHistoryController extends Controller
{
    public function index(Request $request)
    {
        if (!Storage::exists('version_history')) {
            Storage::makeDirectory('version_history');
        }

        $files = Storage::files('version_history');
        $snapshots = [];

        foreach ($files as $file) {
            if (substr($file, -5) !== '.json') {
                continue;
            }

            $id = basename($file, '.json');

            try {
                $raw = Storage::get($file);
                $data = json_decode($raw, true);
                if (!is_array($data)) {
                    $data = [];
                }
            } catch (\Throwable $e) {
                $data = [
                    'note'  => 'Corrupted or unreadable snapshot metadata',
                    'error' => $e->getMessage(),
                ];
            }

            $snapshots[] = [
                'id'         => $data['id']         ?? $id,
                'created_at' => $data['created_at'] ?? null,
                'note'       => $data['note']       ?? '',
                'db_dump'    => $data['db_dump']    ?? null,
                'git_commit' => $data['git_commit'] ?? null,
                'git_status' => $data['git_status'] ?? null,
            ];
        }

        usort($snapshots, function (array $a, array $b) {
            return strcmp($b['id'] ?? '', $a['id'] ?? '');
        });

        return view('settings.version_history', [
            'snapshots' => $snapshots,
        ]);
    }
}
PHP

############################################
# 2) Blade view
############################################
echo "==> Writing resources/views/settings/version_history.blade.php"
mkdir -p "${ROOT}/resources/views/settings"

cat > "${ROOT}/resources/views/settings/version_history.blade.php" << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Version history
        </h2>
    </x-slot>

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
        <div class="bg-white rounded-lg shadow p-4">
            <p class="text-sm text-gray-600 mb-4">
                Local snapshots are stored in
                <code class="font-mono text-xs bg-gray-100 px-1 py-0.5 rounded">
                    storage/app/version_history
                </code>
                and database dumps in
                <code class="font-mono text-xs bg-gray-100 px-1 py-0.5 rounded">
                    storage/app/db_dumps
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
                                <th class="px-3 py-2">Note</th>
                                <th class="px-3 py-2">DB dump</th>
                                <th class="px-3 py-2 whitespace-nowrap">Git commit</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            @foreach($snapshots as $snapshot)
                                <tr>
                                    <td class="px-3 py-2 font-mono text-xs">
                                        {{ $snapshot['id'] ?? '' }}
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700 whitespace-nowrap">
                                        {{ $snapshot['created_at'] ?? '—' }}
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700">
                                        {{ $snapshot['note'] ?? '' }}
                                    </td>
                                    <td class="px-3 py-2 text-xs text-gray-700">
                                        {{ $snapshot['db_dump'] ?? '—' }}
                                    </td>
                                    <td class="px-3 py-2 text-xs font-mono text-gray-700">
                                        {{ \Illuminate\Support\Str::limit($snapshot['git_commit'] ?? '', 10, '') }}
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>

                <p class="mt-4 text-xs text-gray-500">
                    To create a snapshot from CLI:
                    <code class="font-mono bg-gray-100 px-1 py-0.5 rounded">
                        ./scripts/version_snapshot.sh "short note"
                    </code><br>
                    To rollback to a snapshot:
                    <code class="font-mono bg-gray-100 px-1 py-0.5 rounded">
                        ./scripts/version_rollback.sh SNAPSHOT_ID
                    </code>
                </p>
            @endif
        </div>
    </div>
</x-app-layout>
BLADE

############################################
# 3) Routes
############################################
ROUTES_FILE="${ROOT}/routes/web.php"
echo "==> Ensuring /settings/version-history route exists"

if ! grep -q "settings.version-history.index" "${ROUTES_FILE}"; then
  cat >> "${ROUTES_FILE}" << 'ROUTE'

Route::middleware(['web','auth'])->group(function () {
    Route::get('/settings/version-history', [\App\Http\Controllers\VersionHistoryController::class, 'index'])
        ->name('settings.version-history.index');
});
ROUTE
else
  echo "    Route already present, skipping append."
fi

############################################
# 4) version_snapshot.sh
############################################
echo "==> Writing scripts/version_snapshot.sh"

cat > "${ROOT}/scripts/version_snapshot.sh" << 'SH'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VH_DIR="${ROOT}/storage/app/version_history"
DB_DIR="${ROOT}/storage/app/db_dumps"

mkdir -p "${VH_DIR}" "${DB_DIR}"

NOTE="${1:-""}"
SNAP_ID="$(date +%F_%H-%M-%S)"
META_FILE="${VH_DIR}/${SNAP_ID}.json"
DB_DUMP_REL="storage/app/db_dumps/${SNAP_ID}.sql.gz"
DB_DUMP_ABS="${ROOT}/${DB_DUMP_REL}"

echo "==> Creating DB dump to ${DB_DUMP_REL}"
docker compose exec -T postgres sh -lc 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
  | gzip > "${DB_DUMP_ABS}"

GIT_COMMIT="$(cd "${ROOT}" && git rev-parse HEAD 2>/dev/null || echo "")"
GIT_STATUS="$(cd "${ROOT}" && git status --short --branch 2>/dev/null || echo "")"
CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "${META_FILE}" << EOF
{
  "id": "${SNAP_ID}",
  "created_at": "${CREATED_AT}",
  "note": "$(printf '%s' "${NOTE}" | sed 's/"/\\"/g')",
  "db_dump": "${DB_DUMP_REL}",
  "git_commit": "${GIT_COMMIT}",
  "git_status": "$(printf '%s' "${GIT_STATUS}" | sed 's/"/\\"/g')"
}
