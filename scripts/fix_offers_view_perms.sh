#!/usr/bin/env bash
set -euo pipefail

echo "==> fix_offers_view_perms: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/fix_offers_view_perms_${STAMP}"
echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "   - Backing up ${f}"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    cp "$f" "${BACKUP_DIR}/${f}"
  fi
}

# Views we touched recently
backup_file "resources/views/offers/index.blade.php"
backup_file "resources/views/offers/create.blade.php"
backup_file "resources/views/offers/edit.blade.php"
backup_file "resources/views/offers/history.blade.php"
backup_file "resources/views/layouts/navigation.blade.php"

echo "==> Fixing permissions for offers views"

# Ensure dirs are traversable by the webserver
chmod 775 resources/views || true
chmod 775 resources/views/offers || true

# Ensure files are world-readable (rw-rw-r--)
find resources/views/offers -type f -exec chmod 664 {} \; || true
chmod 664 resources/views/layouts/navigation.blade.php || true

echo "==> Current perms for offers views:"
ls -l resources/views/offers || true

echo "==> fix_offers_view_perms: done"
