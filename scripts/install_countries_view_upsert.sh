#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Installing countries view with upsert, guard, and dedupe (idempotent)"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- Drop networks unique indexes temporarily to allow relinks/dedup safely
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

-- Decide/prepare base table
DO $$
DECLARE relkind_char char(1);
DECLARE base_exists bool;
BEGIN
  SELECT relkind INTO relkind_char
  FROM pg_class WHERE oid = to_regclass('public.countries');

  SELECT to_regclass('public.countries_base') IS NOT NULL INTO base_exists;

  IF relkind_char = 'r' AND NOT base_exists THEN
    -- countries is a table; convert it to base
    EXECUTE 'ALTER TABLE countries RENAME TO countries_base';
  END IF;
END$$;

-- Ensure the base table exists now
DO $$
BEGIN
  IF to_regclass('public.countries_base') IS NULL THEN
    RAISE EXCEPTION 'countries_base not found; abort';
  END IF;
END$$;

-- Keep iso2 as varchar(3) so bad inputs reach BEFORE trigger
ALTER TABLE countries_base
  ALTER COLUMN iso2 TYPE varchar(3);

-- Guard on base: invalid -> 'ZZ', uppercase
CREATE OR REPLACE FUNCTION countries_iso2_guard() RETURNS trigger AS $fn$
BEGIN
  IF NEW.iso2 IS NULL OR length(NEW.iso2) <> 2 OR NEW.iso2 !~ '^[A-Za-z]{2}$' THEN
    NEW.iso2 := 'ZZ';
  END IF;
  NEW.iso2 := upper(NEW.iso2);
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_countries_iso2_guard ON countries_base;
CREATE TRIGGER trg_countries_iso2_guard
BEFORE INSERT OR UPDATE ON countries_base
FOR EACH ROW EXECUTE FUNCTION countries_iso2_guard();

-- Drop strict CHECK/unique for dedupe phase (re-add later)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'countries_base'::regclass
      AND conname  = 'countries_iso2_check'
  ) THEN
    EXECUTE 'ALTER TABLE countries_base DROP CONSTRAINT countries_iso2_check';
  END IF;
END$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='countries_iso2_unique_idx') THEN
    EXECUTE 'DROP INDEX countries_iso2_unique_idx';
  END IF;
END$$;

-- Normalize & dedupe countries by iso2 (keep min id), relink networks
UPDATE countries_base SET iso2 = iso2; -- fires guard

DROP TABLE IF EXISTS _cdups;
CREATE TEMP TABLE _cdups AS
SELECT iso2, MIN(id) AS keep_id, ARRAY_AGG(id) AS ids
FROM countries_base
GROUP BY iso2
HAVING COUNT(*) > 1;

UPDATE networks n
SET country_id = d.keep_id
FROM _cdups d
WHERE n.country_id = ANY(d.ids) AND n.country_id <> d.keep_id;

DELETE FROM countries_base c
USING _cdups d
WHERE c.iso2 = d.iso2 AND c.id <> d.keep_id;

-- Recreate strict CHECK on base (two letters) and unique on iso2
ALTER TABLE countries_base
  ADD CONSTRAINT countries_iso2_check CHECK (iso2 ~ '^[A-Z]{2}$');

CREATE UNIQUE INDEX IF NOT EXISTS countries_iso2_unique_idx ON countries_base(iso2);

-- Friendly ZZ
INSERT INTO countries_base(name, iso2, created_at, updated_at)
SELECT 'International','ZZ', now(), now()
WHERE NOT EXISTS (SELECT 1 FROM countries_base WHERE iso2='ZZ');
UPDATE countries_base SET name='International' WHERE iso2='ZZ';

-- Create/replace the updatable view
DROP VIEW IF EXISTS countries;
CREATE VIEW countries AS
SELECT id, name, iso2, created_at, updated_at FROM countries_base;

-- INSTEAD OF triggers on the view to UPSERT into the base
CREATE OR REPLACE FUNCTION countries_view_upsert_ins() RETURNS trigger AS $fn$
DECLARE r countries_base%ROWTYPE;
BEGIN
  INSERT INTO countries_base(name, iso2, created_at, updated_at)
  VALUES (
    COALESCE(NEW.name,'International'),
    NEW.iso2,
    COALESCE(NEW.created_at, now()),
    COALESCE(NEW.updated_at, now())
  )
  ON CONFLICT (iso2) DO UPDATE
    SET name = EXCLUDED.name,
        updated_at = now()
  RETURNING * INTO r;

  NEW.id := r.id;
  NEW.name := r.name;
  NEW.iso2 := r.iso2;
  NEW.created_at := r.created_at;
  NEW.updated_at := r.updated_at;
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_countries_view_ins ON countries;
CREATE TRIGGER trg_countries_view_ins
INSTEAD OF INSERT ON countries
FOR EACH ROW EXECUTE FUNCTION countries_view_upsert_ins();

CREATE OR REPLACE FUNCTION countries_view_upsert_upd() RETURNS trigger AS $fn$
DECLARE r countries_base%ROWTYPE;
BEGIN
  INSERT INTO countries_base(name, iso2, created_at, updated_at)
  VALUES (
    COALESCE(NEW.name,'International'),
    NEW.iso2,
    COALESCE(OLD.created_at, now()),
    now()
  )
  ON CONFLICT (iso2) DO UPDATE
    SET name = EXCLUDED.name,
        updated_at = now()
  RETURNING * INTO r;

  NEW.id := r.id;
  NEW.name := r.name;
  NEW.iso2 := r.iso2;
  NEW.created_at := r.created_at;
  NEW.updated_at := r.updated_at;
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_countries_view_upd ON countries;
CREATE TRIGGER trg_countries_view_upd
INSTEAD OF UPDATE ON countries
FOR EACH ROW EXECUTE FUNCTION countries_view_upsert_upd();

-- Normalize/dedupe networks on (country_id, normalized name), then restore indexes
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

-- Fire normalizer and collapse duplicates
UPDATE networks SET name = name;

DROP TABLE IF EXISTS _net_dups;
CREATE TEMP TABLE _net_dups AS
SELECT country_id, lower(name) AS lname, MIN(id) keep_id, ARRAY_AGG(id) ids
FROM networks
GROUP BY country_id, lower(name)
HAVING COUNT(*) > 1;

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
      FROM _net_dups d
      WHERE m.network_id = ANY(d.ids)
        AND m.network_id <> d.keep_id
    $upd$;
  END IF;
END$$;

DELETE FROM networks n
USING _net_dups d
WHERE n.id = ANY(d.ids) AND n.id <> d.keep_id;

-- Restore uniqueness: (country_id, lower(name))
CREATE UNIQUE INDEX IF NOT EXISTS uniq_networks_country_lowername
ON networks (country_id, lower(name));

-- Smoke test: this must not error and must leave ZZ single
INSERT INTO countries(name, iso2, created_at, updated_at)
VALUES ('International Networks','n/a', now(), now())
RETURNING id, name, iso2;

COMMIT;

\echo === REPORT ===
SELECT
  (SELECT COUNT(*) FROM countries) AS countries,
  (SELECT COUNT(*) FROM networks)  AS networks;
SELECT id, name, iso2 FROM countries WHERE iso2='ZZ' ORDER BY id LIMIT 1;
SQL
