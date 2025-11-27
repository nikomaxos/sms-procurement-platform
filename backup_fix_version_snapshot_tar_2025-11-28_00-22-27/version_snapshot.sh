#!/usr/bin/env bash
set -euo pipefail

# Root of the project (works both on host and in container)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NOTE="${1:-auto}"

# Sanitize note to build an ID suffix
slugify() {
  # to lowercase, replace non-alnum with '-', trim '-'
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//'
}

NOTE_SLUG="$(slugify "$NOTE")"
[ -z "$NOTE_SLUG" ] && NOTE_SLUG="snapshot"

ID="$(date +%F_%H-%M-%S)_${NOTE_SLUG}"

SNAP_DIR="$ROOT/backups/version_history/$ID"
LOG_DIR="$ROOT/storage/app/version_history"
LOG_FILE="$LOG_DIR/snapshots.log"

mkdir -p "$SNAP_DIR" "$LOG_DIR"

echo "==> Creating snapshot: $ID"
echo "==> Directory: $SNAP_DIR"

# ---- Load DB settings from environment / .env ----------------------------

ENV_FILE="$ROOT/.env"

DB_DATABASE="${DB_DATABASE:-}"
DB_USERNAME="${DB_USERNAME:-}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-}"

if [ -f "$ENV_FILE" ]; then
  # simple parser for KEY=VALUE lines (no export, simple quoting)
  get_env() {
    local key="$1"
    local val
    val="$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | head -n1 | cut -d= -f2- || true)"
    # strip surrounding quotes
    val="${val%\"}"
    val="${val#\"}"
    echo "$val"
  }

  [ -z "$DB_DATABASE" ] && DB_DATABASE="$(get_env DB_DATABASE)"
  [ -z "$DB_USERNAME" ] && DB_USERNAME="$(get_env DB_USERNAME)"
  [ -z "$DB_PASSWORD" ] && DB_PASSWORD="$(get_env DB_PASSWORD)"
  [ -z "$DB_HOST" ]     && DB_HOST="$(get_env DB_HOST)"
  [ -z "$DB_PORT" ]     && DB_PORT="$(get_env DB_PORT)"
fi

[ -z "$DB_DATABASE" ] && DB_DATABASE="app"
[ -z "$DB_USERNAME" ] && DB_USERNAME="app"
[ -z "$DB_HOST" ]     && DB_HOST="localhost"
[ -z "$DB_PORT" ]     && DB_PORT="5432"

DB_DUMP_REL="${ID}_db.sql"
DB_DUMP_PATH="$SNAP_DIR/$DB_DUMP_REL"
CODE_ARCHIVE_REL="${ID}_code.tar.gz"
CODE_ARCHIVE_PATH="$SNAP_DIR/$CODE_ARCHIVE_REL"

# Values to store in snapshots.log
DB_DUMP_FIELD="$DB_DUMP_REL"
CODE_ARCHIVE_FIELD="$CODE_ARCHIVE_REL"

echo "==> Ensuring Postgres is reachable and dumping DB..."

# ---------------------------------------------------------------------------
# MODE 1: Host mode with docker compose (original behavior)
# ---------------------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  echo "   [mode] host/docker: using docker compose exec postgres"

  # Check postgres service is up
  set +e
  docker compose ps postgres >/dev/null 2>&1
  PS_RC=$?
  set -e

  if [ $PS_RC -ne 0 ]; then
    echo "ERROR: postgres service is not running."
    echo "       Start it with:"
    echo "         docker compose up -d postgres"
    exit 1
  fi

  echo "   [db] Dumping via docker compose exec -> $DB_DUMP_PATH"
  set +e
  if [ -n "$DB_PASSWORD" ]; then
    # Use PGPASSWORD inside the postgres container
    docker compose exec -T -e "PGPASSWORD=$DB_PASSWORD" postgres \
      pg_dump -U "$DB_USERNAME" "$DB_DATABASE" > "$DB_DUMP_PATH"
  else
    docker compose exec -T postgres \
      pg_dump -U "$DB_USERNAME" "$DB_DATABASE" > "$DB_DUMP_PATH"
  fi
  DUMP_RC=$?
  set -e

  if [ $DUMP_RC -ne 0 ]; then
    echo "ERROR: pg_dump via docker compose failed with exit code $DUMP_RC."
    echo "       The snapshot will be created but without a DB dump."
    DB_DUMP_FIELD="—"
    rm -f "$DB_DUMP_PATH" || true
  fi

# ---------------------------------------------------------------------------
# MODE 2: Container / no-docker mode
# ---------------------------------------------------------------------------
else
  echo "   [mode] container/no-docker: trying local pg_dump"
  if ! command -v pg_dump >/dev/null 2>&1; then
    echo "WARNING: pg_dump not found in this container; skipping DB dump."
    DB_DUMP_FIELD="—"
  else
    echo "   [db] Running pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USERNAME $DB_DATABASE"
    if [ -n "$DB_PASSWORD" ]; then
      export PGPASSWORD="$DB_PASSWORD"
    fi
    set +e
    pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" "$DB_DATABASE" > "$DB_DUMP_PATH"
    DUMP_RC=$?
    set -e
    if [ $DUMP_RC -ne 0 ]; then
      echo "WARNING: pg_dump failed with exit code $DUMP_RC; skipping DB dump."
      DB_DUMP_FIELD="—"
      rm -f "$DB_DUMP_PATH" || true
    fi
  fi
fi

# ---- Archive code tree ---------------------------------------------------

echo "==> Archiving code tree to $CODE_ARCHIVE_PATH"

tar \
  --exclude='./backups' \
  --exclude='./storage/app/version_history' \
  --exclude='./storage/framework/cache' \
  --exclude='./storage/framework/views' \
  --exclude='./storage/logs' \
  --exclude='./node_modules' \
  --exclude='./vendor' \
  -czf "$CODE_ARCHIVE_PATH" .

if [ ! -s "$CODE_ARCHIVE_PATH" ]; then
  echo "ERROR: code archive failed or is empty."
  exit 1
fi

# ---- Git commit info (if available) -------------------------------------

set +e
GIT_COMMIT="$(git rev-parse HEAD 2>/dev/null)"
GIT_RC=$?
set -e
if [ $GIT_RC -ne 0 ] || [ -z "$GIT_COMMIT" ]; then
  GIT_COMMIT="-"
fi

CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TYPE="manual"

NOTE_FIELD="$NOTE"
NOTE_FIELD="${NOTE_FIELD//|//}"   # avoid breaking the pipe-delimited format

echo "==> Appending snapshot entry to $LOG_FILE"

printf '%s|%s|%s|%s|%s|%s|%s\n' \
  "$ID" \
  "$CREATED_AT" \
  "$TYPE" \
  "$NOTE_FIELD" \
  "$DB_DUMP_FIELD" \
  "$CODE_ARCHIVE_FIELD" \
  "$GIT_COMMIT" >> "$LOG_FILE"

echo "==> Snapshot completed."
