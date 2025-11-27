#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Project root: ${ROOT}"

BACKUP_DIR="backup_networks_$(date +%F_%H-%M-%S)"
echo "==> Creating backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

# Backup current (πιθανά σπασμένα) αρχεία
if [ -f app/Http/Controllers/NetworksController.php ]; then
  echo "==> Backing up current NetworksController.php"
  cp app/Http/Controllers/NetworksController.php \
     "${BACKUP_DIR}/NetworksController.php.broken"
fi

if [ -f resources/views/networks/index.blade.php ]; then
  echo "==> Backing up current networks index view"
  cp resources/views/networks/index.blade.php \
     "${BACKUP_DIR}/index.blade.php.broken"
fi

if [ -f resources/views/networks/edit.blade.php ]; then
  echo "==> Backing up current networks edit view"
  cp resources/views/networks/edit.blade.php \
     "${BACKUP_DIR}/edit.blade.php.broken"
fi

echo "==> Restoring networks files from git HEAD"
git restore app/Http/Controllers/NetworksController.php \
           resources/views/networks/index.blade.php \
           resources/views/networks/edit.blade.php

echo "==> Running PHP syntax check for NetworksController inside app container"
docker compose exec app sh -lc 'php -l app/Http/Controllers/NetworksController.php' || {
  echo "!! Syntax error still detected in NetworksController.php inside container."
  exit 1
}

echo "==> Clearing Laravel caches inside app container"
docker compose exec app sh -lc 'php artisan optimize:clear' || true

echo "==> Done. Try opening /networks in the browser now."
