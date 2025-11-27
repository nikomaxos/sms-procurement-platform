#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TS="$(date +%F_%H-%M-%S)"
BACKUP_DIR="$ROOT/backup_fix_version_rollback_${TS}"
mkdir -p "$BACKUP_DIR"

ROLLBACK_FILE="$ROOT/scripts/version_rollback.sh"

if [ -f "$ROLLBACK_FILE" ]; then
  cp "$ROLLBACK_FILE" "$BACKUP_DIR/version_rollback.sh"
  echo "==> Backup: scripts/version_rollback.sh -> $BACKUP_DIR/version_rollback.sh"
else
  echo "==> No existing scripts/version_rollback.sh, creating fresh one."
fi

cat > "$ROLLBACK_FILE" << 'EOS'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ $# -ne 1 ]; then
  echo "Usage: $0 SNAPSHOT_ID" >&2
  exit 1
fi

SNAPSHOT_ID="$1"
SNAP_DIR="$ROOT/backups/version_history/$SNAPSHOT_ID"

echo "==> Rolling back snapshot: $SNAPSHOT_ID"
echo "==> Snapshot directory: $SNAP_DIR"

if [ ! -d "$SNAP_DIR" ]; then
  echo "ERROR: Snapshot directory not found: $SNAP_DIR" >&2
  exit 1
fi

CODE_ARCHIVE="$SNAP_DIR/${SNAPSHOT_ID}_code.tar.gz"
if [ ! -f "$CODE_ARCHIVE" ]; then
  echo "ERROR: Code archive not found: $CODE_ARCHIVE" >&2
  exit 1
fi

# -------------------------------------------------------------------
# Locate DB dump — supports current naming (<id>_db.sql) plus a few
# legacy patterns, to avoid hard failures on older snapshots.
# -------------------------------------------------------------------
DB_DUMP=""

if [ -f "$SNAP_DIR/${SNAPSHOT_ID}_db.sql" ]; then
  DB_DUMP="$SNAP_DIR/${SNAPSHOT_ID}_db.sql"
elif [ -f "$SNAP_DIR/db.sql" ]; then
  DB_DUMP="$SNAP_DIR/db.sql"
elif [ -f "$SNAP_DIR/db.sql.gz" ]; then
  echo "   [db] Found gzipped db.sql.gz, decompressing to temporary file..."
  DB_DUMP="$SNAP_DIR/${SNAPSHOT_ID}_db.tmp.sql"
  gunzip -c "$SNAP_DIR/db.sql.gz" > "$DB_DUMP"
elif [ -f "$SNAP_DIR/${SNAPSHOT_ID}_db.sql.gz" ]; then
  echo "   [db] Found gzipped ${SNAPSHOT_ID}_db.sql.gz, decompressing to temporary file..."
  DB_DUMP="$SNAP_DIR/${SNAPSHOT_ID}_db.tmp.sql"
  gunzip -c "$SNAP_DIR/${SNAPSHOT_ID}_db.sql.gz" > "$DB_DUMP"
fi

if [ -z "${DB_DUMP:-}" ] || [ ! -f "$DB_DUMP" ]; then
  echo "ERROR: DB dump not found in snapshot directory." >&2
  echo "       Looked for:" >&2
  echo "         $SNAP_DIR/${SNAPSHOT_ID}_db.sql" >&2
  echo "         $SNAP_DIR/db.sql" >&2
  echo "         $SNAP_DIR/db.sql.gz" >&2
  echo "         $SNAP_DIR/${SNAPSHOT_ID}_db.sql.gz" >&2
  exit 1
fi

echo "==> Using DB dump: $DB_DUMP"
echo "==> Restoring Postgres database..."

# [Inference] DB settings: follow your .env / docker-compose defaults
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_DATABASE="${DB_DATABASE:-app}"
DB_USERNAME="${DB_USERNAME:-app}"
DB_PASSWORD="${DB_PASSWORD:-app}"

export PGPASSWORD="$DB_PASSWORD"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" "$DB_DATABASE" < "$DB_DUMP"

echo "==> Restoring code from archive: $CODE_ARCHIVE"
tar -xzf "$CODE_ARCHIVE" -C "$ROOT"

echo "==> Rollback completed."
EOS

chmod +x "$ROLLBACK_FILE"

echo "==> New scripts/version_rollback.sh written."
echo "==> To test from host (non-UI), run e.g.:"
echo "    docker compose exec app bash -lc './scripts/version_rollback.sh 2025-11-27_23-10-38_gdb-backups-working'"
