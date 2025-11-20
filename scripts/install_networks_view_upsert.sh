#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Install networks view + UPSERT, normalize names, dedupe (idempotent)"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- 0) Drop any old unique indexes that might block relinks/dedup
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

-- 1) If a view named networks exists, drop it; we will rebuild
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='networks') THEN
    EXECUTE 'DROP VIEW networks';
  END IF;
END$$;

-- 2) Ensure base table exists: rename table -> networks_base once
DO $$
DECLARE relkind_char char(1);
BEGIN
  SELECT relkind INTO relkind_char
  FROM pg_class WHERE oid = to_regclass('public.networks');
  IF relkind_char = 'r' THEN
    EXECUTE 'ALTER TABLE networks RENAME TO networks_base';
  END IF;

  IF to_regclass('public.networks_base') IS NULL THEN
    RAISE EXCEPTION 'networks_base not found; abort';
  END IF;
END$$;

-- 3) Ensure lower_name column exists on base
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='networks_base' AND column_name='lower_name'
  ) THEN
    EXECUTE 'ALTER TABLE networks_base ADD COLUMN lower_name varchar(255)';
  END IF;
END$$;

-- 4) Name normalizer on base: trim, collapse spaces, compute lower_name
CREATE OR REPLACE FUNCTION networks_name_normalize_base() RETURNS trigger AS $fn$
BEGIN
  IF NEW.name IS NULL THEN NEW.name := ''; END IF;
  NEW.name := regexp_replace(btrim(NEW.name), '\s+', ' ', 'g');
  NEW.lower_name := lower(NEW.name);
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_networks_name_normalize_base ON networks_base;
CREATE TRIGGER trg_networks_name_normalize_base
BEFORE INSERT OR UPDATE ON networks_base
FOR EACH ROW EXECUTE FUNCTION networks_name_normalize_base();

-- 5) Normalize existing rows and fill lower_name
UPDATE networks_base SET name = name;  -- fires normalizer

-- 6) Dedupe by (country_id, lower_name); keep MIN(id); relink dependents if any
DROP TABLE IF EXISTS _n_dups;
CREATE TEMP TABLE _n_dups AS
SELECT country_id, lower_name, MIN(id) AS keep_id, ARRAY_AGG(id) AS ids
FROM networks_base
GROUP BY country_id, lower_name
HAVING COUNT(*) > 1;

DO $$
DECLARE has_mncs boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='network_mncs'
  ) INTO has_mncs;

  IF has_mncs THEN
    EXECUTE $upd$
      UPDATE network_mncs m
      SET network_id = d.keep_id
      FROM _n_dups d
      WHERE m.network_id = ANY(d.ids)
        AND m.network_id <> d.keep_id
    $upd$;
  END IF;
END$$;

DELETE FROM networks_base n
USING _n_dups d
WHERE n.country_id = d.country_id
  AND n.lower_name = d.lower_name
  AND n.id <> d.keep_id;

-- 7) Add a REAL UNIQUE CONSTRAINT on (country_id, lower_name)
--    (this enables ON CONFLICT ON CONSTRAINT ...)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid='networks_base'::regclass AND conname='networks_country_lowername_unique'
  ) THEN
    EXECUTE 'ALTER TABLE networks_base DROP CONSTRAINT networks_country_lowername_unique';
  END IF;
END$$;
ALTER TABLE networks_base
  ADD CONSTRAINT networks_country_lowername_unique UNIQUE (country_id, lower_name);

-- 8) Recreate the networks view
CREATE OR REPLACE VIEW networks AS
SELECT id, country_id, name, lower_name, created_at, updated_at
FROM networks_base;

-- 9) INSTEAD OF INSERT/UPDATE triggers on the view to perform an UPSERT
CREATE OR REPLACE FUNCTION networks_view_upsert_ins() RETURNS trigger AS $fn$
DECLARE r networks_base%ROWTYPE;
BEGIN
  -- Normalize here as well (view-side) so ON CONFLICT hits correct key;
  -- base trigger also runs, so we're consistent.
  NEW.name := regexp_replace(btrim(COALESCE(NEW.name,'')), '\s+', ' ', 'g');
  NEW.lower_name := lower(NEW.name);

  INSERT INTO networks_base(country_id, name, lower_name, created_at, updated_at)
  VALUES (NEW.country_id, NEW.name, NEW.lower_name, COALESCE(NEW.created_at, now()), COALESCE(NEW.updated_at, now()))
  ON CONFLICT ON CONSTRAINT networks_country_lowername_unique DO UPDATE
    SET name = EXCLUDED.name,
        updated_at = now()
  RETURNING * INTO r;

  NEW.id := r.id; NEW.created_at := r.created_at; NEW.updated_at := r.updated_at;
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_networks_view_ins ON networks;
CREATE TRIGGER trg_networks_view_ins
INSTEAD OF INSERT ON networks
FOR EACH ROW EXECUTE FUNCTION networks_view_upsert_ins();

CREATE OR REPLACE FUNCTION networks_view_upsert_upd() RETURNS trigger AS $fn$
DECLARE r networks_base%ROWTYPE;
BEGIN
  NEW.name := regexp_replace(btrim(COALESCE(NEW.name,'')), '\s+', ' ', 'g');
  NEW.lower_name := lower(NEW.name);

  INSERT INTO networks_base(country_id, name, lower_name, created_at, updated_at)
  VALUES (NEW.country_id, NEW.name, NEW.lower_name, COALESCE(OLD.created_at, now()), now())
  ON CONFLICT ON CONSTRAINT networks_country_lowername_unique DO UPDATE
    SET name = EXCLUDED.name,
        updated_at = now()
  RETURNING * INTO r;

  NEW.id := r.id; NEW.created_at := r.created_at; NEW.updated_at := r.updated_at;
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_networks_view_upd ON networks;
CREATE TRIGGER trg_networks_view_upd
INSTEAD OF UPDATE ON networks
FOR EACH ROW EXECUTE FUNCTION networks_view_upsert_upd();

-- 10) Smoke test: insert dup name with different case/spacing — must upsert, not error
INSERT INTO networks(country_id, name) VALUES
  ((SELECT id FROM countries WHERE iso2='ZZ' LIMIT 1), '  Fix   Line ')
RETURNING id, country_id, name, lower_name;

COMMIT;

\echo === REPORT ===
SELECT
  (SELECT COUNT(*) FROM networks) AS networks_count,
  (SELECT COUNT(*) FROM (SELECT DISTINCT country_id, lower_name FROM networks) s) AS unique_key_count;
SQL
