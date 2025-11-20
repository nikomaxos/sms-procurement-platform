#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Temporarily relax countries.iso2 to varchar(3)"
$DC exec -T postgres bash -lc '
  set -e
  export PGPASSWORD=secret
  cat > /tmp/relax.sql <<SQL
BEGIN;

-- Drop any existing CHECK constraint(s) on iso2 (name-agnostic)
DO \$\$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = ''countries''::regclass
      AND contype = ''c''
  LOOP
    EXECUTE ''ALTER TABLE countries DROP CONSTRAINT '' || quote_ident(r.conname);
  END LOOP;
END
\$\$;

-- Widen to varchar(3)
ALTER TABLE countries ALTER COLUMN iso2 TYPE varchar(3);

COMMIT;
SQL
  psql -U app -d app -v ON_ERROR_STOP=1 -f /tmp/relax.sql
  rm -f /tmp/relax.sql
'
echo "==> Done. Now run the Countries/Networks import with: Auto + Clear existing."
