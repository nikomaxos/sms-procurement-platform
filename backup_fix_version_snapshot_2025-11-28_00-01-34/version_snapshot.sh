#!/usr/bin/env bash
set -euo pipefail

##
## Create a snapshot before running a change script.
##
## Usage:
##   ./scripts/version_snapshot.sh "Adding Create Offer Button" [auto|manual]
##

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NOTE="${1:-}"
TYPE="${2:-manual}"

if [[ -z "$NOTE" ]]; then
  echo "Usage: $0 \"short note\" [auto|manual]" >&2
  exit 1
fi

# Build snapshot id: timestamp + slug of note
ts="$(date -u +%F_%H-%M-%S)"
slug="$(printf '%s' "$NOTE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-_')"
if [[ -z "$slug" ]]; then
  slug="snapshot"
fi
SNAPSHOT_ID="${ts}_${slug}"

BACKUP_ROOT="$ROOT/backups/version_history"
SNAPSHOT_DIR="$BACKUP_ROOT/$SNAPSHOT_ID"
mkdir -p "$SNAPSHOT_DIR"

echo "==> Creating snapshot: $SNAPSHOT_ID"
echo "==> Directory: $SNAPSHOT_DIR"

# Git info (best-effort)
GIT_COMMIT="$(git rev-parse --short=10 HEAD 2>/dev/null || echo 'unknown')"
GIT_STATUS="$(git status --porcelain=v1 2>/dev/null || true)"
printf '%s\n' "$GIT_STATUS" > "$SNAPSHOT_DIR/git_status.txt"

# Ensure Postgres (service: postgres) is up
echo "==> Ensuring Postgres service is up..."
docker compose up -d postgres >/dev/null 2>&1 || true

if ! docker compose ps --services --filter "status=running" | grep -qx 'postgres'; then
  echo "ERROR: postgres service is not running." >&2
  echo "       Start it with:" >&2
  echo "         docker compose up -d postgres" >&2
  exit 1
fi

# DB dump
echo "==> Dumping Postgres database (gzipped)..."
DB_DUMP="$SNAPSHOT_DIR/db.sql.gz"
docker compose exec -T postgres sh -lc '
  set -euo pipefail
  : "${POSTGRES_DB:?POSTGRES_DB not set}"
  : "${POSTGRES_USER:?POSTGRES_USER not set}"
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"
' | gzip > "$DB_DUMP"

# Code archive (project tree)
echo "==> Archiving application code..."
CODE_ARCHIVE="$SNAPSHOT_DIR/code.tar.gz"

tar \
  --ignore-failed-read \
  --exclude='./backups' \
  --exclude='./.backups' \
  --exclude='./vendor' \
  --exclude='./node_modules' \
  --exclude='./.git' \
  -czf "$CODE_ARCHIVE" .

# Append to ledger (pipe-separated)
LEDGER_DIR="$ROOT/storage/app/version_history"
LEDGER_FILE="$LEDGER_DIR/snapshots.log"
mkdir -p "$LEDGER_DIR"

CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# NOTE: avoid '|' in NOTE to keep parsing simple.
LINE="${SNAPSHOT_ID}|${CREATED_AT}|${NOTE}|${TYPE}|${DB_DUMP#$ROOT/}|${CODE_ARCHIVE#$ROOT/}|${GIT_COMMIT}"

echo "$LINE" >> "$LEDGER_FILE"

echo "==> Snapshot recorded:"
echo "    ID:           $SNAPSHOT_ID"
echo "    Created at:   $CREATED_AT (UTC)"
echo "    Note:         $NOTE"
echo "    Type:         $TYPE"
echo "    DB dump:      ${DB_DUMP#$ROOT/}"
echo "    Code archive: ${CODE_ARCHIVE#$ROOT/}"
echo "    Git commit:   $GIT_COMMIT"
echo
echo "Rollback command:"
echo "    ./scripts/version_rollback.sh $SNAPSHOT_ID"
