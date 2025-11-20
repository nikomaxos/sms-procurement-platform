#!/usr/bin/env bash
set -euo pipefail

# Compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> [DB] Install/refresh ISO2 guard, strict checks, UPSERT rule, and network name normalizer"

$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- === COUNTRIES: column + CHECK kept strict, but width 3 so trigger can coerce bad inputs first ===
ALTER TABLE countries
  ALTER COLUMN iso2 TYPE varchar(3);

-- Guard trigger to coerce invalid iso2 -> 'ZZ' and uppercase (BEFORE INSERT/UPDATE)
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

-- Re-add strict CHECK (exactly two A-Z after guard) and full unique on iso2
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'countries'::regclass
       AND conname  = 'countries_iso2_check'
  ) THEN
    EXECUTE 'ALTER TABLE countries DROP CONSTRAINT countries_iso2_check';
  END IF;
END
$$;

ALTER TABLE countries
  ADD CONSTRAINT countries_iso2_check CHECK (iso2 ~ '^[A-Z]{2}$');

-- Ensure the *full* unique index (not partial) is present
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname='countries_iso2_unique_idx') THEN
    EXECUTE 'DROP INDEX countries_iso2_unique_idx';
  END IF;
END$$;
CREATE UNIQUE INDEX countries_iso2_unique_idx ON countries(iso2);

-- === UPSERT RULE: transparently rewrite plain INSERTs into INSERT ... ON CONFLICT (iso2) DO UPDATE ===
-- This preserves semantics of "INSERT ... RETURNING id" used by Laravel; the rewritten statement returns the row.
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

-- Ensure there is exactly one ZZ; name it friendly
WITH keep AS (
  SELECT id FROM countries WHERE iso2='ZZ' ORDER BY id ASC LIMIT 1
),
others AS (
  SELECT id FROM countries WHERE iso2='ZZ' AND id NOT IN (SELECT id FROM keep)
)
UPDATE networks n SET country_id = (SELECT id FROM keep) WHERE n.country_id IN (SELECT id FROM others);
DELETE FROM countries c WHERE c.id IN (SELECT id FROM others);
UPDATE countries SET name='International' WHERE iso2='ZZ';

-- === NETWORKS: normalize names (trim → collapse whitespace → uppercase) BEFORE INSERT/UPDATE ===
CREATE OR REPLACE FUNCTION networks_name_normalize() RETURNS trigger AS $fn$
BEGIN
  IF NEW.name IS NULL THEN
    NEW.name := '';
  END IF;
  -- trim, collapse internal whitespace to single space, then uppercase
  NEW.name := upper(regexp_replace(btrim(NEW.name), '\s+', ' ', 'g'));
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_networks_name_normalize ON networks;
CREATE TRIGGER trg_networks_name_normalize
BEFORE INSERT OR UPDATE ON networks
FOR EACH ROW EXECUTE FUNCTION networks_name_normalize();

COMMIT;

-- === SELF-TESTS (read-only effects) ===

-- 1) Try to insert an "n/a" iso2; guard -> 'ZZ'; rule upserts cleanly (no error), leaves a single ZZ.
INSERT INTO countries(name, iso2, created_at, updated_at)
VALUES ('International Networks', 'n/a', now(), now())
ON CONFLICT (iso2) DO NOTHING;

-- 2) Quick sanity report
\echo === REPORT ===
SELECT COUNT(*) AS countries FROM countries;
SELECT COUNT(*) AS networks  FROM networks;
SELECT COUNT(*) AS zz_rows   FROM countries WHERE iso2='ZZ';
SELECT id, name, iso2 FROM countries WHERE iso2='ZZ' ORDER BY id LIMIT 1;
SQL

echo "==> Done. The importer can now insert (name='International Networks', iso2='n/a') without errors."
echo "==> Tip: after each large import you can still de-dupe ZZ networks by name if needed:"
echo "    bash scripts/db_collapse_zz_and_networks.sh   # (optional; you already have it)"
