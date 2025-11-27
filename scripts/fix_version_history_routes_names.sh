#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VIEW_FILE="$ROOT/resources/views/settings/version-history.blade.php"
TS="$(date +%F_%H-%M-%S)"
BACKUP_DIR="$ROOT/backup_fix_version_history_routes_names_${TS}"

mkdir -p "$BACKUP_DIR"

if [ -f "$VIEW_FILE" ]; then
  cp "$VIEW_FILE" "$BACKUP_DIR/version-history.blade.php"
  echo "==> Backup: $VIEW_FILE -> $BACKUP_DIR/version-history.blade.php"
else
  echo "!! ERROR: View file not found at $VIEW_FILE"
  exit 1
fi

echo "==> Updating route names in view..."

# Use the existing routes we already created earlier:
#   version-history.snapshot
#   version-history.destroy
sed -i "s/settings.version-history.snapshot/version-history.snapshot/g" "$VIEW_FILE"
sed -i "s/settings.version-history.destroy/version-history.destroy/g" "$VIEW_FILE"

echo "==> Clearing compiled views inside app container (if docker available)..."
if command -v docker >/dev/null 2>&1; then
  docker compose exec app php artisan view:clear || true
fi

echo "==> Done. Reload /settings/version-history in your browser."
