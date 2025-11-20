#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Guard + dedupe countries/networks, view-based upsert (idempotent)"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- 0) Drop networks unique index *first* so relinks can't violate it
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

-- A) Resolve base table (first run it's 'countries'; later 'countries_base')
DO $$
DECLARE base_tbl text;
BEGIN
  base_tbl := CASE WHEN to_regclass('public.countries_base') IS NOT NULL
                   THEN 'countries_base' ELSE 'countries' END;

  -- widen to let bad inputs hit trigger
  EXECUTE format('ALTER TABLE %I ALTER COLUMN iso2 TYPE varchar(3)', base_tbl);

  -- ISO2 guard: invalid -> 'ZZ', uppercase
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

  -- drop strict checks for dedupe phase
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = base_tbl::regclass AND conname='countries_iso2_check')
  THEN
    EXECUTE format('ALTER TABLE %I DROP CONSTRAINT countries_iso2_check', base_tbl);
  END IF;

  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='countries_iso2_unique_idx')
  THEN
    EXECUTE 'DROP INDEX countries_iso2_unique_idx';
  END IF;

  -- normalize (fires guard)
  EXECUTE format('UPDATE %I SET iso2 = iso2', base_tbl);

  -- dedupe countries by iso2 (keep min id), relink networks
  EXECUTE format($q$
    DROP TABLE IF EXISTS _cdups;
    CREATE TEMP TABLE _cdups AS
    SELECT iso2, MIN(id) AS keep_id, ARRAY_AGG(id) AS ids
    FROM %I GROUP BY iso2 HAVING COUNT(*) > 1;
  $q$, base_tbl);

  UPDATE networks n
  SET country_id = d.keep_id
  FROM _cdups d
  WHERE n.country_id = ANY(d.ids) AND n.country_id <> d.keep_id;

  EXECUTE format($q$
    DELETE FROM %I c
    USING _cdups d
    WHERE c.iso2 = d.iso2 AND c.id <> d.keep_id;
  $q$, base_tbl);
END$$;

-- B) Normalize + dedupe networks by (country_id, lower(name))
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

UPDATE networks SET name = name;

DROP TABLE IF EXISTS _net_dups;
CREATE TEMP TABLE _net_dups AS
SELECT country_id, lower(name) AS lname, MIN(id) AS keep_id, ARRAY_AGG(id) AS ids
FROM networks
GROUP BY country_id, lower(name)
HAVING COUNT(*) > 1;

-- relink dependents if table exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema='public' AND table_name='network_mncs') THEN
    UPDATE network_mncs m
    SET network_id = d.keep_id
    FROM _net_dups d
    WHERE m.network_id = ANY(d.ids) AND m.network_id <> d.keep_id;
  END IF;
END$$;

DELETE FROM networks n
USING _net_dups d
WHERE n.id = ANY(d.ids) AND n.id <> d.keep_id;

-- C) Re-add strict checks + unique indexes
DO $$
DECLARE base_tbl text;
BEGIN
  base_tbl := CASE WHEN to_regclass('public.countries_base') IS NOT NULL
                   THEN 'countries_base' ELSE 'countries' END;

  EXECUTE format($q$
    ALTER TABLE %I
      ALTER COLUMN iso2 TYPE varchar(2)
      USING UPPER(SUBSTRING(iso2 FROM 1 FOR 2)),
      ADD CONSTRAINT countries_iso2_check CHECK (iso2 ~ '^[A-Z]{2}$');
  $q$, base_tbl);

  EXECUTE format('CREATE UNIQUE INDEX IF NOT EXISTS countries_iso2_unique_idx ON %I(iso2)', base_tbl);
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_networks_country_lowername
  ON networks (country_id, lower(name));

-- D) Swap to VIEW w/ INSTEAD OF triggers (first run only)
DO $$
BEGIN
  IF to_regclass('public.countries_base') IS NULL THEN
    ALTER TABLE countries RENAME TO countries_base;

    CREATE OR REPLACE VIEW countries AS
    SELECT id, name, iso2, created_at, updated_at FROM countries_base;

    -- INSERT: real UPSERT; keep "International" for ZZ
    CREATE OR REPLACE FUNCTION countries_view_ins() RETURNS trigger AS $v$
    DECLARE r countries_base%ROWTYPE;
    BEGIN
      INSERT INTO countries_base(name, iso2, created_at, updated_at)
      VALUES (COALESCE(NEW.name,'International'), NEW.iso2,
              COALESCE(NEW.created_at, now()), COALESCE(NEW.updated_at, now()))
      ON CONFLICT (iso2) DO UPDATE
        SET name = CASE WHEN countries_base.iso2='ZZ'
                        THEN countries_base.name       -- keep "International"
                        ELSE EXCLUDED.name END,
            updated_at = now()
      RETURNING * INTO r;
      RETURN r;
    END;
    $v$ LANGUAGE plpgsql;
    CREATE TRIGGER trg_countries_view_ins
    INSTEAD OF INSERT ON countries
    FOR EACH ROW EXECUTE FUNCTION countries_view_ins();

    -- UPDATE passthrough
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

    -- DELETE passthrough
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

-- E) Ensure single ZZ row and friendly name
DO $$
DECLARE base_tbl text;
BEGIN
  base_tbl := CASE WHEN to_regclass('public.countries_base') IS NOT NULL
                   THEN 'countries_base' ELSE 'countries' END;

  EXECUTE format($q$
    INSERT INTO %I(name, iso2, created_at, updated_at)
    VALUES ('International','ZZ', now(), now())
    ON CONFLICT (iso2) DO UPDATE SET name='International', updated_at=now();
  $q$, base_tbl);
END$$;

COMMIT;

-- F) Smoke test via VIEW: should not rename ZZ or error
INSERT INTO countries(name, iso2, created_at, updated_at)
VALUES ('International Networks','n/a', now(), now())
RETURNING id, name, iso2;

\echo === REPORT ===
SELECT COUNT(*) AS countries FROM countries;
SELECT COUNT(*) AS networks  FROM networks;
SELECT id, name, iso2 FROM countries WHERE iso2='ZZ' ORDER BY id LIMIT 1;
SQL
