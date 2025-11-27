#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT="${1:-}"

if [[ -z "$SNAPSHOT" ]]; then
  echo "Usage: $0 SNAPSHOT_NAME" >&2
  exit 1
fi

APP_DIR="/var/www/html"
cd "$APP_DIR"

SNAPSHOT_DIR="$APP_DIR/backups/version_history/$SNAPSHOT"
DB_DUMP="$SNAPSHOT_DIR/${SNAPSHOT}_db.sql"

if [[ ! -f "$DB_DUMP" ]]; then
  echo "ERROR: DB dump not found at: $DB_DUMP" >&2
  exit 1
fi

echo "==> Rolling back snapshot: $SNAPSHOT"
echo "==> Snapshot directory: $SNAPSHOT_DIR"
echo "==> Using DB dump: $DB_DUMP"

# --- Read DB connection info from .env ---
get_env() {
  local key="$1"
  local line value
  line="$(grep -E "^${key}=" .env || true)"
  value="${line#${key}=}"
  value="${value%$'\r'}"
  # strip optional surrounding quotes
  value="${value%\"}"; value="${value#\"}"
  value="${value%\'}"; value="${value#\'}"
  printf '%s\n' "$value"
}

DB_DATABASE="$(get_env DB_DATABASE)"
DB_USERNAME="$(get_env DB_USERNAME)"
DB_PASSWORD="$(get_env DB_PASSWORD)"
DB_HOST="$(get_env DB_HOST)"
DB_PORT="$(get_env DB_PORT)"

: "${DB_HOST:=postgres}"
: "${DB_PORT:=5432}"

if [[ -z "$DB_DATABASE" || -z "$DB_USERNAME" ]]; then
  echo "ERROR: DB_DATABASE or DB_USERNAME missing from .env" >&2
  exit 1
fi

export PGPASSWORD="$DB_PASSWORD"

PSQL_BASE=(psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME")

echo "==> Preparing clean database '$DB_DATABASE' on $DB_HOST:$DB_PORT as $DB_USERNAME"

# First try: drop & recreate the database (needs CREATEDB / owner rights)
set +e
"${PSQL_BASE[@]}" -d postgres <<SQL
DO \$\$
BEGIN
   PERFORM pg_terminate_backend(pid)
   FROM pg_stat_activity
   WHERE datname = '${DB_DATABASE}'
     AND pid <> pg_backend_pid();
END
\$\$;
DROP DATABASE IF EXISTS "${DB_DATABASE}";
CREATE DATABASE "${DB_DATABASE}" OWNER "${DB_USERNAME}";
SQL
DROP_RC=$?
set -e

if [[ $DROP_RC -ne 0 ]]; then
  echo "!! WARNING: DROP DATABASE failed (likely permissions). Falling back to dropping schema public in $DB_DATABASE" >&2
  "${PSQL_BASE[@]}" -d "$DB_DATABASE" -c "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public AUTHORIZATION \"${DB_USERNAME}\";" 
fi

echo "==> Restoring Postgres database from dump..."
"${PSQL_BASE[@]}" -d "$DB_DATABASE" -f "$DB_DUMP"

echo "==> Database restore completed successfully."

echo "==> Fixing Laravel storage/bootstrap permissions (defensive)"
chmod -R ug+rwX storage bootstrap/cache 2>/dev/null || true
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true

echo "==> Finished DB rollback for snapshot: $SNAPSHOT"
