#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"

echo "==> Looking for latest backup_offers_* directory..."
LATEST_BACKUP_DIR="$(ls -dt backup_offers_* 2>/dev/null | head -n1 || true)"

if [ -z "$LATEST_BACKUP_DIR" ]; then
  echo "!! No backup_offers_* directory found. Cannot rollback automatically."
  exit 1
fi

echo "==> Latest backup dir: ${LATEST_BACKUP_DIR}"

SRC="${LATEST_BACKUP_DIR}/app/Http/Controllers/OffersController.php"
DEST="app/Http/Controllers/OffersController.php"

if [ ! -f "$SRC" ]; then
  echo "!! ${SRC} not found in latest backup. Aborting."
  exit 1
fi

mkdir -p "$(dirname "$DEST")"

cp "$SRC" "$DEST"

echo "==> Restored ${DEST} from ${SRC}"
echo "==> Rollback complete. Try reloading /offers or /offers/create in your browser."
