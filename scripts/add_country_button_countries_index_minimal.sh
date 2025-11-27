#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_countries_index_minimal_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/resources/views/countries"

if [ -f "resources/views/countries/index.blade.php" ]; then
  cp "resources/views/countries/index.blade.php" "${BACKUP_DIR}/resources/views/countries/" || true
fi

echo "==> Patching resources/views/countries/index.blade.php to add 'Add Country' button..."

perl -0pi -e 's#<div class="overflow-x-auto rounded-lg border bg-white">#<div class="overflow-x-auto rounded-lg border bg-white">
            <div class="flex justify-end mb-3 px-4 pt-3">
                <a href="{{ route(\'countries.create\') }}"
                   class="inline-flex items-center px-4 py-2 border border-green-300 text-sm font-medium rounded-md shadow-sm bg-green-100 text-green-800 hover:bg-green-200">
                    Add Country
                </a>
            </div>#' resources/views/countries/index.blade.php

echo "==> Done. File patched. Backup stored in: ${BACKUP_DIR}"
