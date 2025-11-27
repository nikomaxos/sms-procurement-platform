#!/usr/bin/env bash
set -euo pipefail

echo "==> fix_offers_index_blade_v1: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/fix_offers_index_blade_v1_${STAMP}"
echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "   - Backing up ${f}"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    cp "$f" "${BACKUP_DIR}/${f}"
  else
    echo "   - WARNING: ${f} not found, nothing to back up"
  fi
}

TARGET="resources/views/offers/index.blade.php"
backup_file "$TARGET"

if [[ ! -f "$TARGET" ]]; then
  echo "!! ${TARGET} does not exist, aborting."
  exit 1
fi

echo "==> Removing illegal 'use ...' lines from offers/index.blade.php"

# Remove use-statements that are invalid inside @php blocks
perl -pi -e 's/^\s*use\s+App\\Models\\Country;.*$//;' "$TARGET"
perl -pi -e 's/^\s*use\s+App\\Models\\Network;.*$//;' "$TARGET"
perl -pi -e 's/^\s*use\s+App\\Models\\Supplier;.*$//;' "$TARGET"
perl -pi -e 's/^\s*use\s+App\\Models\\SupplierConnection;.*$//;' "$TARGET"
perl -pi -e 's/^\s*use\s+App\\Models\\DropdownItem;.*$//;' "$TARGET"
perl -pi -e 's/^\s*use\s+Illuminate\\Support\\Facades\\DB;.*$//;' "$TARGET"

echo "==> Rewriting class usages to fully-qualified names"

# Replace bare model/facade references with fully-qualified names
perl -pi -e 's/\bCountry::/\\App\\Models\\Country::/g' "$TARGET"
perl -pi -e 's/\bNetwork::/\\App\\Models\\Network::/g' "$TARGET"
perl -pi -e 's/\bSupplier::/\\App\\Models\\Supplier::/g' "$TARGET"
perl -pi -e 's/\bSupplierConnection::/\\App\\Models\\SupplierConnection::/g' "$TARGET"
perl -pi -e 's/\bDropdownItem::/\\App\\Models\\DropdownItem::/g' "$TARGET"
perl -pi -e 's/\bDB::/\\Illuminate\\Support\\Facades\\DB::/g' "$TARGET"

echo "==> Snippet around the @php block (for sanity check):"
nl -ba "$TARGET" | sed -n '1,80p' | sed -n '/@php/,+20p' || true

echo "==> Clearing compiled views inside the app container"
docker compose exec -T app php artisan view:clear || true

echo "==> fix_offers_index_blade_v1: done"
