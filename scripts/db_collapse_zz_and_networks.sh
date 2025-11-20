#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Collapse ZZ countries AND dedupe ZZ networks by name (case-insensitive)"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- Ensure a canonical ZZ exists
INSERT INTO countries(name, iso2, created_at, updated_at)
SELECT 'International','ZZ', now(), now()
WHERE NOT EXISTS (SELECT 1 FROM countries WHERE iso2='ZZ');

-- Keep = lowest id ZZ; Others = the rest
DROP TABLE IF EXISTS _zz_keep;
CREATE TEMP TABLE _zz_keep AS
SELECT id FROM countries WHERE iso2='ZZ' ORDER BY id ASC LIMIT 1;

DROP TABLE IF EXISTS _zz_others;
CREATE TEMP TABLE _zz_others AS
SELECT id FROM countries WHERE iso2='ZZ' AND id NOT IN (SELECT id FROM _zz_keep);

-- Build groups of duplicate ZZ networks by lower(name) across ALL ZZ rows
DROP TABLE IF EXISTS _zz_net_dups;
CREATE TEMP TABLE _zz_net_dups AS
SELECT lower(n.name) AS lname,
       MIN(n.id)     AS keep_id,
       ARRAY_AGG(n.id) AS ids
FROM networks n
WHERE n.country_id IN (SELECT id FROM countries WHERE iso2='ZZ')
GROUP BY lower(n.name)
HAVING COUNT(*) > 1;

-- Relink known dependents of networks (network_mncs) to the keep_id
DO $$
DECLARE v_exists boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name='network_mncs'
  ) INTO v_exists;

  IF v_exists THEN
    EXECUTE $upd$
      UPDATE network_mncs m
      SET network_id = d.keep_id
      FROM _zz_net_dups d
      WHERE m.network_id = ANY(d.ids)
        AND m.network_id <> d.keep_id
    $upd$;
  END IF;
END$$;

-- Delete duplicate network rows (keep one per lname)
DELETE FROM networks n
USING _zz_net_dups d
WHERE n.id = ANY(d.ids) AND n.id <> d.keep_id;

-- Now move remaining ZZ networks on "other" ZZ rows to the canonical ZZ id
UPDATE networks
SET country_id = (SELECT id FROM _zz_keep)
WHERE country_id IN (SELECT id FROM _zz_others);

-- Drop the extra ZZ country rows
DELETE FROM countries c WHERE c.id IN (SELECT id FROM _zz_others);

-- Friendly name for ZZ
UPDATE countries SET name='International' WHERE id=(SELECT id FROM _zz_keep);

COMMIT;

-- Report
\echo === REPORT ===
SELECT COUNT(*) AS zz_rows FROM countries WHERE iso2='ZZ';
SELECT COUNT(*) AS zz_networks FROM networks WHERE country_id=(SELECT id FROM _zz_keep);
SQL
