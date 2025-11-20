#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Apply guard + dedupe countries/networks, recreate constraints, add upsert rule"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- A) Allow bad inputs to reach trigger
ALTER TABLE countries ALTER COLUMN iso2 TYPE varchar(3);

-- B) Countries ISO2 guard (invalid -> 'ZZ', uppercase)
CREATE OR REPLACE FUNCTION countries_iso2_guard() RETURNS trigger AS $fn$
BEGIN
  IF NEW.iso2 IS NULL OR length(NEW.iso2) <> 2 OR NEW.iso2 !~ '^[A-Za-z]{2}$' THEN
    NEW.iso2 := 'ZZ';
  END IF;
  NEW.iso2 := upper(NEW.iso2);
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_countries_iso2_guard ON countries;
CREATE TRIGGER trg_countries_iso2_guard
BEFORE INSERT OR UPDATE ON countries
FOR EACH ROW EXECUTE FUNCTION countries_iso2_guard();

-- C) Drop strict countries CHECK/unique (we’ll recreate later)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'countries'::regclass
      AND conname  = 'countries_iso2_check'
  ) THEN
    EXECUTE 'ALTER TABLE countries DROP CONSTRAINT countries_iso2_check';
  END IF;
END$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='countries_iso2_unique_idx') THEN
    EXECUTE 'DROP INDEX countries_iso2_unique_idx';
  END IF;
END$$;

-- D) Drop networks unique index on (country_id, lower(name)) to allow relinking
DO $$
DECLARE idx text;
BEGIN
  FOR idx IN
    SELECT indexname
    FROM pg_indexes
    WHERE schemaname='public'
      AND tablename='networks'
      AND (
        indexname='uniq_networks_country_lowername'
        OR indexdef ILIKE '%(country_id,%lower%name%'
        OR indexdef ILIKE '%lower((name%'
      )
  LOOP
    EXECUTE 'DROP INDEX '||quote_ident(idx);
  END LOOP;
END$$;

-- E) Normalize existing countries (fires guard), then dedupe by iso2
UPDATE countries SET iso2 = iso2;

DROP TABLE IF EXISTS _cdups;
CREATE TEMP TABLE _cdups AS
SELECT iso2, MIN(id) AS keep_id, ARRAY_AGG(id) AS ids
FROM countries
GROUP BY iso2
HAVING COUNT(*) > 1;

UPDATE networks n
SET country_id = d.keep_id
FROM _cdups d
WHERE n.country_id = ANY(d.ids) AND n.country_id <> d.keep_id;

DELETE FROM countries c
USING _cdups d
WHERE c.iso2 = d.iso2 AND c.id <> d.keep_id;

-- F) Networks name normalizer (trim -> collapse spaces -> UPPER), then dedupe
CREATE OR REPLACE FUNCTION networks_name_normalize() RETURNS trigger AS $fn$
BEGIN
  IF NEW.name IS NULL THEN NEW.name := ''; END IF;
  NEW.name := upper(regexp_replace(btrim(NEW.name), '\s+', ' ', 'g'));
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_networks_name_normalize ON networks;
CREATE TRIGGER trg_networks_name_normalize
BEFORE INSERT OR UPDATE ON networks
FOR EACH ROW EXECUTE FUNCTION networks_name_normalize();

-- Normalize current rows
UPDATE networks SET name = name;

-- Build duplicate groups by (country_id, lower(name))
DROP TABLE IF EXISTS _net_dups;
CREATE TEMP TABLE _net_dups AS
SELECT country_id, lower(name) AS lname, MIN(id) AS keep_id, ARRAY_AGG(id) AS ids
FROM networks
GROUP BY country_id, lower(name)
HAVING COUNT(*) > 1;

-- If network_mncs exists, relink to keep_id
DO $$
DECLARE v_exists boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='network_mncs'
  ) INTO v_exists;

  IF v_exists THEN
    EXECUTE $upd$
      UPDATE network_mncs m
      SET network_id = d.keep_id
      FROM _net_dups d
      WHERE m.network_id = ANY(d.ids)
        AND m.network_id <> d.keep_id
    $upd$;
  END IF;
END$$;

-- Remove duplicate network rows
DELETE FROM networks n
USING _net_dups d
WHERE n.id = ANY(d.ids) AND n.id <> d.keep_id;

-- G) Recreate strict countries CHECK and unique index, and networks unique
ALTER TABLE countries
  ADD CONSTRAINT countries_iso2_check CHECK (iso2 ~ '^[A-Z]{2}$');

CREATE UNIQUE INDEX countries_iso2_unique_idx ON countries(iso2);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_networks_country_lowername
  ON networks (country_id, lower(name));

-- H) COUNTRIES UPSERT RULE: plain INSERT -> ON CONFLICT (iso2) UPDATE + RETURNING *
DROP RULE IF EXISTS countries_insert_upsert ON countries;
CREATE RULE countries_insert_upsert AS
ON INSERT TO countries
DO INSTEAD
INSERT INTO countries (name, iso2, created_at, updated_at)
VALUES (
  COALESCE(NEW.name, 'International'),
  NEW.iso2,
  COALESCE(NEW.created_at, now()),
  COALESCE(NEW.updated_at, now())
)
ON CONFLICT (iso2) DO UPDATE
SET name = EXCLUDED.name,
    updated_at = now()
RETURNING *;

-- I) Ensure exactly one ZZ, friendly name, and relink leftovers
WITH keep AS (
  SELECT id FROM countries WHERE iso2='ZZ' ORDER BY id ASC LIMIT 1
), others AS (
  SELECT id FROM countries WHERE iso2='ZZ' AND id NOT IN (SELECT id FROM keep)
)
UPDATE networks n SET country_id = (SELECT id FROM keep) WHERE n.country_id IN (SELECT id FROM others);
DELETE FROM countries c WHERE c.id IN (SELECT id FROM others);
UPDATE countries SET name='International' WHERE iso2='ZZ';

COMMIT;

-- J) Smoke test for the importer’s problematic row
INSERT INTO countries(name, iso2, created_at, updated_at)
VALUES ('International Networks','n/a', now(), now())
ON CONFLICT (iso2) DO NOTHING;

\echo === REPORT ===
SELECT COUNT(*) AS countries FROM countries;
SELECT COUNT(*) AS networks  FROM networks;
SELECT id, name, iso2 FROM countries WHERE iso2='ZZ' ORDER BY id LIMIT 1;
SQL
