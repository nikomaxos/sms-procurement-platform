#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Temporarily relax countries.iso2 to varchar(3)"
$DC exec -T postgres bash -lc '
  set -e
  export PGPASSWORD=secret
  psql -U app -d app -v ON_ERROR_STOP=1 <<SQL
BEGIN;
-- drop any check on iso2 if it exists (ignore errors quietly)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'countries'::regclass
       AND contype = 'c'
       AND conname = 'countries_iso2_check'
  ) THEN
    EXECUTE 'ALTER TABLE countries DROP CONSTRAINT countries_iso2_check';
  END IF;
END$$;
ALTER TABLE countries ALTER COLUMN iso2 TYPE varchar(3);
COMMIT;
SQL
'
echo "==> Done. Now run your Countries/Networks import with 'Auto' + 'Clear existing'."
