#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BACKUP_DIR="backup_networks_hard_reset_$(date +%F_%H-%M-%S)"
echo "==> Backup dir: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Πάρε backup τα τωρινά (σπασμένα) αρχεία
for f in \
  app/Http/Controllers/NetworksController.php \
  resources/views/networks/index.blade.php \
  resources/views/networks/edit.blade.php
do
  if [ -f "$f" ]; then
    echo "==> Backing up $f"
    cp "$f" "$BACKUP_DIR/$(basename "$f").broken"
  fi
done

echo "==> Restoring controller + views from git HEAD"
git restore \
  app/Http/Controllers/NetworksController.php \
  resources/views/networks/index.blade.php \
  resources/views/networks/edit.blade.php

echo "==> Syntax check inside app container and clear caches"
docker compose exec app sh -lc '
  cd /var/www/html &&
  php -l app/Http/Controllers/NetworksController.php &&
  php artisan optimize:clear || true
'

echo "==> Done. Test /networks and /networks/{id}/edit in browser."
