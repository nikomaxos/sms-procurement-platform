#!/usr/bin/env bash
set -euo pipefail

echo "==> fix_offers_fk_and_migrations_v2: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/fix_offers_fk_and_migrations_${STAMP}"
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

# ---------------------------------------------------------------------------
# 1) Back up the four migrations we know about (if present)
# ---------------------------------------------------------------------------
MIG1="database/migrations/2025_11_23_012523_000000_create_supplier_offers_table.php"
MIG2="database/migrations/2025_11_23_012523_000001_create_supplier_offer_history_table.php"
MIG3="database/migrations/2025_11_23_012636_000000_create_supplier_offers_table.php"
MIG4="database/migrations/2025_11_23_012636_000001_create_supplier_offer_history_table.php"

backup_file "$MIG1"
backup_file "$MIG2"
backup_file "$MIG3"
backup_file "$MIG4"

# ---------------------------------------------------------------------------
# 2) Remove the *duplicate* later pair (012636...) so they never run
# ---------------------------------------------------------------------------
for f in "$MIG3" "$MIG4"; do
  if [[ -f "$f" ]]; then
    echo "==> Moving duplicate migration ${f} to backup"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    mv "$f" "${BACKUP_DIR}/${f}"
  fi
done

# ---------------------------------------------------------------------------
# 3) Patch the remaining 012523 migrations:
#    - Drop FK to 'countries' (country_id should just be a plain indexed column)
# ---------------------------------------------------------------------------
if ! command -v perl >/dev/null 2>&1; then
  echo "!! 'perl' is required for patching and was not found in PATH."
  echo "   Install perl or edit the migration manually to remove FK to 'countries'."
  exit 1
fi

if [[ -f "$MIG1" ]]; then
  echo "==> Patching $MIG1 to remove foreign key to countries"

  # Replace any statement starting with $table->foreignId('country_id') ... ;
  # with a simple nullable indexed foreignId without FK constraint.
  perl -0pi -e "s/\\\$table->foreignId\\('country_id'\\).*?;/\$table->foreignId('country_id')->nullable()->index();/s" "$MIG1" || true

  # Also handle the case where we might have used foreignIdFor(Country::class)
  perl -0pi -e "s/\\\$table->foreignIdFor\\(\\\s*App\\\\Models\\\\Country::class\\\s*\\).*?;/\$table->unsignedBigInteger('country_id')->nullable()->index();/s" "$MIG1" || true
fi

if [[ -f "$MIG2" ]]; then
  echo "==> Patching $MIG2 (history) to remove foreign key to countries if present"

  perl -0pi -e "s/\\\$table->foreignId\\('country_id'\\).*?;/\$table->foreignId('country_id')->nullable()->index();/s" "$MIG2" || true
  perl -0pi -e "s/\\\$table->foreignIdFor\\(\\\s*App\\\\Models\\\\Country::class\\\s*\\).*?;/\$table->unsignedBigInteger('country_id')->nullable()->index();/s" "$MIG2" || true
fi

echo "==> Migration status BEFORE rerun:"
docker compose exec -T app php artisan migrate:status || true

echo "==> Running migrations..."
set +e
docker compose exec -T app php artisan migrate --force
MIG_EXIT=$?
set -e

if [[ $MIG_EXIT -ne 0 ]]; then
  echo "!! php artisan migrate failed with exit code $MIG_EXIT"
  echo "   Check the error above; all original migrations are backed up under ${BACKUP_DIR}"
  exit $MIG_EXIT
fi

echo "==> Clearing caches"
docker compose exec -T app php artisan optimize:clear || true

echo "==> fix_offers_fk_and_migrations_v2: done"
