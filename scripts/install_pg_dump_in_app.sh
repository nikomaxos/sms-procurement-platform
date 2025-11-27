#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TIMESTAMP="$(date +%F_%H-%M-%S)"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/install_pg_dump_in_app_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"

# Log to file + stdout
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Installing pg_dump (postgresql-client) inside 'app' container..."
echo "==> Log file: $LOG_FILE"

docker compose exec -T app bash -lc '
  set -e
  echo "-> Inside container: $(uname -a)"
  echo "-> Current user: $(id)"

  if command -v pg_dump >/dev/null 2>&1; then
    echo "pg_dump already present at: $(command -v pg_dump)"
    pg_dump --version || true
    exit 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    echo "-> Detected Debian/Ubuntu (apt-get available)"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends postgresql-client
    apt-get clean
    rm -rf /var/lib/apt/lists/*
  elif command -v apk >/dev/null 2>&1; then
    echo "-> Detected Alpine (apk available)"
    apk update
    # Package names may differ slightly across Alpine versions; adjust if needed.
    apk add --no-cache postgresql-client || apk add --no-cache postgresql15-client || true
  else
    echo "ERROR: Neither apt-get nor apk found. Cannot auto-install pg_dump in this container."
    exit 1
  fi

  echo "-> Verifying pg_dump installation..."
  if command -v pg_dump >/dev/null 2>&1; then
    echo "pg_dump path: $(command -v pg_dump)"
    pg_dump --version || true
  else
    echo "ERROR: pg_dump still not found after attempted installation."
    exit 1
  fi
'

echo "==> Done. Check above for any errors."
