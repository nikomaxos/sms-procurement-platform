#!/usr/bin/env bash
set -euo pipefail

echo "==> fix_offers_migration_line_v3: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/fix_offers_migration_line_v3_${STAMP}"
echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

MIG1="database/migrations/2025_11_23_012523_000000_create_supplier_offers_table.php"
MIG2="database/migrations/2025_11_23_012523_000001_create_supplier_offer_history_table.php"

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "   - Backing up ${f}"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    cp "$f" "${BACKUP_DIR}/${f}"
  fi
}

backup_file "$MIG1"
backup_file "$MIG2"

echo "==> Fixing stray '->foreignId('country_id')' lines (adding \$table->)"
for f in "$MIG1" "$MIG2"; do
  if [[ -f "$f" ]]; then
    perl -pi -e "s/^\s*->foreignId\('country_id'\)/            \$table->foreignId('country_id')/" "$f"
  fi
done

echo "==> Snippet from supplier_offers migration:"
if [[ -f "$MIG1" ]]; then
  sed -n '8,25p' "$MIG1"
fi

echo "==> Snippet from supplier_offer_history migration:"
if [[ -f "$MIG2" ]]; then
  sed -n '8,25p' "$MIG2"
fi

echo "==> Running migrations..."
docker compose exec -T app php artisan migrate --force

echo "==> Clearing caches"
docker compose exec -T app php artisan optimize:clear || true

echo "==> fix_offers_migration_line_v3: done"
