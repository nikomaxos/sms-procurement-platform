#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Install countries.iso2 guard (coerce invalid to 'ZZ') and backfill"
$DC exec -T postgres bash -lc "set -e
export PGPASSWORD=secret
cat >/tmp/iso2_guard.sql <<'SQL'
DO \$DO\$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname = 'countries_iso2_guard'
  ) THEN
    CREATE FUNCTION countries_iso2_guard() RETURNS trigger AS \$fn\$
    BEGIN
      IF NEW.iso2 IS NULL OR length(NEW.iso2) <> 2 OR NEW.iso2 !~ '^[A-Za-z]{2}\$' THEN
        NEW.iso2 := 'ZZ';
      END IF;
      NEW.iso2 := upper(NEW.iso2);
      RETURN NEW;
    END;
    \$fn\$ LANGUAGE plpgsql;
  END IF;
END
\$DO\$;

DROP TRIGGER IF EXISTS trg_countries_iso2_guard ON countries;
CREATE TRIGGER trg_countries_iso2_guard
BEFORE INSERT OR UPDATE ON countries
FOR EACH ROW EXECUTE FUNCTION countries_iso2_guard();

UPDATE countries
SET iso2 = 'ZZ'
WHERE iso2 IS NULL OR length(iso2) <> 2 OR iso2 !~ '^[A-Za-z]{2}\$';
SQL
psql -U app -d app -v ON_ERROR_STOP=1 -f /tmp/iso2_guard.sql
"
echo "==> Done. Now re-run the importer (Auto + Clear existing)."
