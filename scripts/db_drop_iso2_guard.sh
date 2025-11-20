#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T postgres bash -lc 'export PGPASSWORD=secret; psql -U app -d app -v ON_ERROR_STOP=1 -c "
DROP TRIGGER IF EXISTS trg_countries_iso2_guard ON countries;
DROP FUNCTION IF EXISTS countries_iso2_guard();
"'
echo "Dropped iso2 guard."
