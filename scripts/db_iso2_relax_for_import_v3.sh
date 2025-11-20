#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Relax countries.iso2 to varchar(3) and drop any CHECK constraints"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- Drop all CHECK constraints on countries (name-agnostic)
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'countries'::regclass
      AND contype = 'c'
  LOOP
    EXECUTE 'ALTER TABLE countries DROP CONSTRAINT ' || quote_ident(r.conname);
  END LOOP;
END
$$;

-- Widen the column
ALTER TABLE countries ALTER COLUMN iso2 TYPE varchar(3);

COMMIT;
SQL
echo "OK: iso2 widened. Now rerun your Countries/Networks import (Auto + Clear existing)."
