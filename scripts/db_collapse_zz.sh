#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Collapse ZZ duplicates to a single country and relink dependents"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- Find canonical ZZ (lowest id)
WITH zz AS (
  SELECT id FROM countries WHERE iso2='ZZ' ORDER BY id ASC LIMIT 1
), dups AS (
  SELECT id FROM countries WHERE iso2='ZZ' AND id NOT IN (SELECT id FROM zz)
)
-- Relink networks to canonical ZZ
UPDATE networks n
SET country_id = (SELECT id FROM zz)
WHERE country_id IN (SELECT id FROM dups);

-- Remove duplicate ZZ rows
DELETE FROM countries c WHERE c.id IN (SELECT id FROM dups);

-- Enforce friendly name for the remaining ZZ
UPDATE countries SET name='International' WHERE iso2='ZZ';

COMMIT;

-- Show result
SELECT COUNT(*) AS zz_rows FROM countries WHERE iso2='ZZ';
SQL
echo "==> Done."
