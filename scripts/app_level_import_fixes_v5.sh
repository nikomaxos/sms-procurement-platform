#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Countries/networks guard + dedupe + view-based upsert (idempotent)"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- A) Decide base table name (before/after first run)
DO $$
DECLARE base_tbl text;
BEGIN
  IF to_regclass('public.countries_base') IS NOT NULL THEN
    base_tbl := 'countries_base';
  ELSE
    base_tbl := 'countries';
  END IF;

  -- widen iso2 to 3 so bad inputs hit the guard first
  EXECUTE format('ALTER TABLE %I ALTER COLUMN iso2 TYPE varchar(3)', base_tbl);

  -- ISO2 guard (invalid -> 'ZZ', uppercase)
  CREATE OR REPLACE FUNCTION countries_iso2_guard() RETURNS trigger AS $fn$
  BEGIN
    IF NEW.iso2 IS NULL OR length(NEW.iso2) <> 2 OR NEW.iso2 !~ '^[A-Za-z]{2}$' THEN
      NEW.iso2 := 'ZZ';
    END IF;
    NEW.iso2 := upper(NEW.iso2);
    RETURN NEW;
  END;
  $fn$ LANGUAGE plpgsql;

  EXECUTE format('DROP TRIGGER IF EXISTS trg_countries_iso2_guard ON %I', base_tbl);
  EXECUTE format('CREATE TRIGGER trg_countries_iso2_guard BEFORE INSERT OR UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION countries_iso2_guard()', base_tbl);

  -- drop strict CHECK/unique for dedupe, re-add later
  PERFORM 1 FROM pg_constraint WHERE conrelid = base_tbl::regclass AND conname='countries_iso2_check';
  IF FOUND THEN
    EXECUTE format('ALTER TABLE %I DROP CONSTRAINT countries_iso2_check', base_tbl);
  END IF;

  PERFORM 1
  FROM pg_indexes
  WHERE schemaname='public' AND indexname='countries_iso2_unique_idx';
  IF FOUND THEN
    EXECUTE 'DROP INDEX countries_iso2_unique_idx';
  END IF;

  -- Normalize existing (fires guard)
  EXECUTE format('UPDATE %I SET iso2 = iso2', base_tbl);

  -- Dedupe countries by iso2 (keep lowest id); relink networks
  EXECUTE format($q$
    DROP TABLE IF EXISTS _cdups;
    CREATE TEMP TABLE _cdups AS
    SELECT iso2, MIN(id) AS keep_id, ARRAY_AGG(id) AS ids
    FROM %I
    GROUP BY iso2
    HAVING COUNT(*) > 1;
  $q$, base_tbl);

  EXECUTE format($q$
    UPDATE networks n
    SET country_id = d.keep_id
    FROM _cdups d
    WHERE n.country_id = ANY(d.ids) AND n.country_id <> d.keep_id;
  $q$);

  EXECUTE format($q$
    DELETE FROM %I c
    USING _cdups d
    WHERE c.iso2 = d.iso2 AND c.id <> d.keep_id;
  $q$, base_tbl);

  -- networks: drop unique on (country_id, lower(name)) to allow dedupe/relink
  FOR base_tbl IN
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
    EXECUTE 'DROP INDEX '||quote_ident(base_tbl);
  END LOOP;

  -- name normalizer (trim/collapse spaces/UPPER)
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

  -- normalize current names + dedupe
  UPDATE networks SET name = name;

  DROP TABLE IF EXISTS _net_dups;
  CREATE TEMP TABLE _net_dups AS
  SELECT country_id, lower(name) AS lname, MIN(id) AS keep_id, ARRAY_AGG(id) AS ids
  FROM networks
  GROUP BY country_id, lower(name)
  HAVING COUNT(*) > 1;

  -- relink network_mncs if exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='network_mncs'
  ) THEN
    UPDATE network_mncs m
    SET network_id = d.keep_id
    FROM _net_dups d
    WHERE m.network_id = ANY(d.ids)
      AND m.network_id <> d.keep_id;
  END IF;

  DELETE FROM networks n
  USING _net_dups d
  WHERE n.id = ANY(d.ids) AND n.id <> d.keep_id;

  -- Re-add strict check + unique on base table
  EXECUTE format($q$
    ALTER TABLE %I
      ALTER COLUMN iso2 TYPE varchar(2)
      USING UPPER(SUBSTRING(iso2 FROM 1 FOR 2)),
      ADD CONSTRAINT countries_iso2_check CHECK (iso2 ~ '^[A-Z]{2}$');
  $q$, base_tbl);

  EXECUTE format('CREATE UNIQUE INDEX countries_iso2_unique_idx ON %I(iso2)', base_tbl);

  -- Recreate networks uniqueness by (country_id, lower(name))
  CREATE UNIQUE INDEX IF NOT EXISTS uniq_networks_country_lowername
    ON networks (country_id, lower(name));

END$$;

-- B) Replace table with view proxy (first run only)
DO $$
BEGIN
  IF to_regclass('public.countries_base') IS NULL THEN
    -- rename physical table
    ALTER TABLE countries RENAME TO countries_base;

    -- view presenting same columns
    CREATE OR REPLACE VIEW countries AS
    SELECT id, name, iso2, created_at, updated_at FROM countries_base;

    -- INSTEAD OF INSERT: real UPSERT with RETURNING semantics
    CREATE OR REPLACE FUNCTION countries_view_ins() RETURNS trigger AS $v$
    DECLARE r countries_base%ROWTYPE;
    BEGIN
      INSERT INTO countries_base(name, iso2, created_at, updated_at)
      VALUES (COALESCE(NEW.name,'International'), NEW.iso2,
              COALESCE(NEW.created_at, now()), COALESCE(NEW.updated_at, now()))
      ON CONFLICT (iso2) DO UPDATE
        SET name = EXCLUDED.name, updated_at = now()
      RETURNING * INTO r;
      RETURN r;
    END;
    $v$ LANGUAGE plpgsql;

    CREATE TRIGGER trg_countries_view_ins
    INSTEAD OF INSERT ON countries
    FOR EACH ROW EXECUTE FUNCTION countries_view_ins();

    -- Pass-through UPDATE/DELETE (optional but nice)
    CREATE OR REPLACE FUNCTION countries_view_upd() RETURNS trigger AS $v$
    DECLARE r countries_base%ROWTYPE;
    BEGIN
      UPDATE countries_base
      SET name = NEW.name,
          iso2 = NEW.iso2,
          updated_at = now()
      WHERE id = OLD.id
      RETURNING * INTO r;
      RETURN r;
    END;
    $v$ LANGUAGE plpgsql;

    CREATE TRIGGER trg_countries_view_upd
    INSTEAD OF UPDATE ON countries
    FOR EACH ROW EXECUTE FUNCTION countries_view_upd();

    CREATE OR REPLACE FUNCTION countries_view_del() RETURNS trigger AS $v$
    BEGIN
      DELETE FROM countries_base WHERE id = OLD.id;
      RETURN OLD;
    END;
    $v$ LANGUAGE plpgsql;

    CREATE TRIGGER trg_countries_view_del
    INSTEAD OF DELETE ON countries
    FOR EACH ROW EXECUTE FUNCTION countries_view_del();
  END IF;
END$$;

-- C) Ensure single ZZ row named nicely (on base)
DO $$
DECLARE base_tbl text;
BEGIN
  base_tbl := CASE WHEN to_regclass('public.countries_base') IS NOT NULL THEN 'countries_base' ELSE 'countries' END;

  EXECUTE format($q$
    INSERT INTO %I(name, iso2, created_at, updated_at)
    VALUES ('International','ZZ', now(), now())
    ON CONFLICT (iso2) DO UPDATE SET name='International', updated_at=now();
  $q$, base_tbl);
END$$;

COMMIT;

-- D) Smoke test via the VIEW (app writes here): should succeed, no error
INSERT INTO countries(name, iso2, created_at, updated_at)
VALUES ('International Networks','n/a', now(), now())
RETURNING id, name, iso2;

\echo === REPORT ===
SELECT COUNT(*) AS countries FROM countries;
SELECT COUNT(*) AS networks  FROM networks;
SELECT id, name, iso2 FROM countries WHERE iso2='ZZ' ORDER BY id LIMIT 1;
SQL
