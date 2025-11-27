#!/usr/bin/env bash
set -euo pipefail

echo "==> fix_offers_migrations_and_migrate: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Showing migration status (so you can see the new ones):"
docker compose exec -T app php artisan migrate:status || true

echo "==> Running migrations..."
docker compose exec -T app php artisan migrate --force

echo "==> Clearing caches (just in case)"
docker compose exec -T app php artisan optimize:clear

echo "==> fix_offers_migrations_and_migrate: done"
