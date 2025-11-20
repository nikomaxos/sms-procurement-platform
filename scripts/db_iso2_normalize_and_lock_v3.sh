#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Normalize iso2 values to ISO-2, fix duplicates, and re-add constraints"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- Uppercase & coerce invalid to ZZ
UPDATE countries SET iso2 = UPPER(iso2);
UPDATE countries
   SET iso2 = 'ZZ'
 WHERE iso2 IS NULL
    OR iso2 !~ '^[A-Z]{2}$';

-- Merge duplicates per iso2; keep lowest id; relink networks
WITH dups AS (
  SELECT iso2, MIN(id) AS keep_id, ARRAY_AGG(id) AS ids
  FROM countries
  GROUP BY iso2
  HAVING COUNT(*) > 1
)
UPDATE networks n
SET country_id = d.keep_id
FROM dups d
WHERE n.country_id = ANY(d.ids) AND n.country_id <> d.keep_id;

DELETE FROM countries c
USING dups d
WHERE c.iso2 = d.iso2 AND c.id <> d.keep_id;

-- Shrink back to varchar(2)
ALTER TABLE countries
  ALTER COLUMN iso2 TYPE varchar(2)
  USING UPPER(SUBSTRING(iso2 FROM 1 FOR 2));

-- Re-add strict CHECK and unique index
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

COMMIT;

-- quick report
\\echo
\\echo === After normalize ===
SELECT COUNT(*) AS countries FROM countries;
SELECT COUNT(*) AS networks  FROM networks;
SQL
echo "OK: iso2 restored to varchar(2) with constraints."
