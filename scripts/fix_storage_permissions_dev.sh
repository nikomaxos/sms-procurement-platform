#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Project root: ${ROOT}"
echo "==> Fixing Laravel storage & cache permissions (DEV MODE)"

/usr/bin/docker compose exec app sh -lc '
  set -e
  cd /var/www/html

  echo "==> Before:"
  ls -ld storage storage/framework storage/framework/views || true

  echo "==> Ensuring directories exist"
  mkdir -p storage/framework/views
  mkdir -p storage/logs

  echo "==> Applying permissive chmod (777) for dev"
  chmod -R 777 storage bootstrap/cache || true

  echo "==> After:"
  ls -ld storage storage/framework storage/framework/views || true
'

echo "==> Done. Try reloading the app in the browser."
