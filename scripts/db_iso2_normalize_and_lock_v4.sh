#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Normalize countries.iso2, merge duplicates, and re-add constraints"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- 1) Uppercase + coerce invalid to 'ZZ'
UPDATE countries SET iso2 = UPPER(iso2);
UPDATE countries
   SET iso2 = 'ZZ'
 WHERE iso2 IS NULL
    OR iso2 !~ '^[A-Z]{2}$';

-- 2) Build duplicate list once, visible to subsequent statements
DROP TABLE IF EXISTS _dups;
CREATE TEMP TABLE _dups AS
SELECT iso2, MIN(id) AS keep_id, ARRAY_AGG(id) AS ids
FROM countries
GROUP BY iso2
HAVING COUNT(*) > 1;

-- 3) Relink networks to the survivor id
UPDATE networks n
SET country_id = d.keep_id
FROM _dups d
WHERE n.country_id = ANY(d.ids) AND n.country_id <> d.keep_id;

-- 4) Remove extra country rows per iso2
DELETE FROM countries c
USING _dups d
WHERE c.iso2 = d.iso2 AND c.id <> d.keep_id;

-- 5) Shrink back to varchar(2)
ALTER TABLE countries
  ALTER COLUMN iso2 TYPE varchar(2)
  USING UPPER(SUBSTRING(iso2 FROM 1 FOR 2));

-- 6) Re-add strict CHECK and unique index
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'countries'::regclass
      AND conname  = 'countries_iso2_check'
  ) THEN
    EXECUTE 'ALTER TABLE countries
             ADD CONSTRAINT countries_iso2_check
             CHECK (iso2 ~ ''^[A-Z]{2}$'')';
  END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS countries_iso2_unique_idx ON countries(iso2);

-- 7) Quick report
\echo
\echo === After normalize ===
SELECT COUNT(*) AS countries FROM countries;
SELECT COUNT(*) FILTER (WHERE iso2 = 'ZZ') AS zz_countries FROM countries;

COMMIT;
SQL
echo "OK."
