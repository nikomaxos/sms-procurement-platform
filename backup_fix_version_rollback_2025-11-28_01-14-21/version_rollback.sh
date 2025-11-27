#!/usr/bin/env bash
set -euo pipefail

##
## Roll back code + DB to a previously captured snapshot.
##
## Usage:
##   ./scripts/version_rollback.sh SNAPSHOT_ID
##
## Behaviour:
##   - If 'docker' CLI is available (host mode):
##       * uses 'docker compose' to restore DB via postgres service
##       * stops/starts app + web services via 'docker compose'
##   - If 'docker' is NOT available (container mode, e.g. app container):
##       * restores code directly from code.tar.gz
##       * restores DB via 'psql' using .env DB_* variables
##       * NO docker calls at all
##
##   When called from the UI, NON_INTERACTIVE=1 is set and the confirmation
##   prompt is skipped.
##

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SNAPSHOT_ID="${1:-}"

if [[ -z "$SNAPSHOT_ID" ]]; then
  echo "Usage: $0 SNAPSHOT_ID" >&2
  exit 1
fi

SNAPSHOT_DIR="$ROOT/backups/version_history/$SNAPSHOT_ID"
DB_DUMP="$SNAPSHOT_DIR/db.sql.gz"
CODE_ARCHIVE="$SNAPSHOT_DIR/code.tar.gz"

if [[ ! -d "$SNAPSHOT_DIR" ]]; then
  echo "ERROR: Snapshot directory not found: $SNAPSHOT_DIR" >&2
  exit 1
fi

if [[ ! -f "$DB_DUMP" ]]; then
  echo "ERROR: DB dump not found: $DB_DUMP" >&2
  exit 1
fi

if [[ ! -f "$CODE_ARCHIVE" ]]; then
  echo "ERROR: Code archive not found: $CODE_ARCHIVE" >&2
  exit 1
fi

echo "==> Preparing to restore snapshot: $SNAPSHOT_ID"
echo "    From directory: $SNAPSHOT_DIR"
echo
echo "This will:"
echo "  - Backup current code under backups/pre_rollback_*/ (best effort)"
echo "  - Overwrite the project tree with the archived code"
echo "  - Restore the Postgres database from the snapshot dump"
echo

if [[ "${NON_INTERACTIVE:-0}" != "1" ]]; then
  read -r -p "Type YES to confirm: " answer

  if [[ "$answer" != "YES" ]]; then
    echo "Aborted."
    exit 1
  fi
else
  echo "==> NON_INTERACTIVE=1 set, skipping interactive confirmation."
fi

# Best-effort pre-rollback backup of current code.
PRE_DIR="$ROOT/backups/pre_rollback_$(date -u +%F_%H-%M-%S)"

if mkdir -p "$PRE_DIR"; then
  echo "==> Backing up current code to: $PRE_DIR"
  if ! tar \
    --ignore-failed-read \
    --exclude='./backups' \
    --exclude='./.backups' \
    --exclude='./vendor' \
    --exclude='./node_modules' \
    --exclude='./.git' \
    -czf "$PRE_DIR/code_before.tar.gz" .; then
    echo "WARNING: Pre-rollback code backup tar failed; continuing WITHOUT pre-rollback backup." >&2
  fi
else
  echo "WARNING: Could not create pre-rollback backup directory: $PRE_DIR" >&2
  echo "         Continuing WITHOUT pre-rollback code backup." >&2
fi

# Decide mode: host (docker available) vs container (no docker)
if command -v docker >/dev/null 2>&1; then
  MODE="docker"
else
  MODE="direct"
fi

if [[ "$MODE" == "docker" ]]; then
  echo "==> Running rollback via docker compose (host mode)..."

  # Ensure Postgres is up
  echo "==> Ensuring Postgres service is up..."
  docker compose up -d postgres >/dev/null 2>&1 || true

  if ! docker compose ps --services --filter "status=running" | grep -qx 'postgres'; then
    echo "ERROR: postgres service is not running." >&2
    echo "       Start it with:" >&2
    echo "         docker compose up -d postgres" >&2
    exit 1
  fi

  # Stop app + web
  echo "==> Stopping app and web services..."
  docker compose stop app web >/dev/null 2>&1 || true

  # Restore code
  echo "==> Restoring application code from snapshot..."
  tar -xzf "$CODE_ARCHIVE" -C "$ROOT"

  # Restore DB via postgres container
  echo "==> Restoring Postgres database from snapshot (via docker compose)..."
  gunzip -c "$DB_DUMP" | docker compose exec -T postgres sh -lc '
    set -euo pipefail
    : "${POSTGRES_DB:?POSTGRES_DB not set}"
    : "${POSTGRES_USER:?POSTGRES_USER not set}"
    psql -U "$POSTGRES_USER" "$POSTGRES_DB"
  '

  # Start app + web again
  echo "==> Starting app and web services..."
  docker compose up -d app web >/dev/null 2>&1 || true

else
  echo "==> Running rollback in direct container mode (no docker CLI)..."

  # Put app in maintenance, if possible
  if command -v php >/dev/null 2>&1; then
    php artisan down || true
  fi

  # Restore code
  echo "==> Restoring application code from snapshot..."
  tar -xzf "$CODE_ARCHIVE" -C "$ROOT"

  # Read DB connection from .env
  if [[ ! -f "$ROOT/.env" ]]; then
    echo "ERROR: .env not found at $ROOT/.env; cannot determine DB connection." >&2
    exit 1
  fi

  env_val() {
    local key="$1"
    local line
    line="$(grep -E "^${key}=" "$ROOT/.env" | head -n1 || true)"
    if [[ -z "$line" ]]; then
      return 1
    fi
    # Remove KEY= prefix
    line="${line#${key}=}"
    # Strip surrounding quotes if present
    line="${line%\"}"
    line="${line#\"}"
    line="${line%\'}"
    line="${line#\'}"
    echo "$line"
  }

  DB_HOST="$(env_val DB_HOST || echo 'postgres')"
  DB_DATABASE="$(env_val DB_DATABASE || env_val POSTGRES_DB || echo '')"
  DB_USERNAME="$(env_val DB_USERNAME || env_val POSTGRES_USER || echo '')"
  DB_PASSWORD="$(env_val DB_PASSWORD || env_val POSTGRES_PASSWORD || echo '')"

  if [[ -z "$DB_HOST" || -z "$DB_DATABASE" || -z "$DB_USERNAME" ]]; then
    echo "ERROR: Could not resolve DB connection parameters from .env (DB_HOST/DB_DATABASE/DB_USERNAME)." >&2
    exit 1
  fi

  if ! command -v psql >/dev/null 2>&1; then
    echo "ERROR: psql client not found in this container." >&2
    echo "       Install postgresql-client in the app image, OR run rollback from the host CLI." >&2
    exit 1
  fi

  echo "==> Restoring Postgres database from snapshot (via psql)..."
  export PGPASSWORD="$DB_PASSWORD"
  if ! gunzip -c "$DB_DUMP" | psql -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_DATABASE"; then
    echo "ERROR: psql restore failed." >&2
    exit 1
  fi
  unset PGPASSWORD

  if command -v php >/dev/null 2>&1; then
    php artisan up || true
  fi
fi

echo "==> Rollback complete. Snapshot restored: $SNAPSHOT_ID"
