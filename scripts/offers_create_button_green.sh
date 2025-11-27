#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_offers_create_button_green_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/resources/views/offers"

# Backup του index.blade.php
if [ -f "resources/views/offers/index.blade.php" ]; then
  cp resources/views/offers/index.blade.php "${BACKUP_DIR}/resources/views/offers/" || true
fi

echo "==> Updating Create Offer button styling in offers index..."

perl -0pi -e 's~<a\s+href="{{ route\(\'offers.create\'\) }}".*?Create Offer\s*</a>~<a href="{{ route(\'offers.create\') }}"\n   class="inline-flex items-center px-4 py-2 border border-green-300 text-sm font-medium rounded-md shadow-sm bg-green-100 text-green-800 hover:bg-green-200">\n    Create Offer\n</a>~s' resources/views/offers/index.blade.php

echo "==> Done. Create Offer button is now light green."
