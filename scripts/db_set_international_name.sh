#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 -c \
  "UPDATE countries SET name='International' WHERE iso2='ZZ';"
