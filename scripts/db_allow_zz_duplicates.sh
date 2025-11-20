#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Allow duplicates for ZZ only (partial unique index) + keep guard"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
-- Keep iso2 at varchar(3) so trigger can coerce bad inputs before checks
ALTER TABLE countries ALTER COLUMN iso2 TYPE varchar(3);

-- (Re)install guard trigger: invalid -> 'ZZ', uppercase
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

-- Strict content check: exactly two uppercase letters
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

-- Replace global unique index with partial unique (all except ZZ)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname='countries_iso2_unique_idx') THEN
    EXECUTE 'DROP INDEX countries_iso2_unique_idx';
  END IF;
END
$$;
CREATE UNIQUE INDEX countries_iso2_unique_idx ON countries(iso2) WHERE iso2 <> 'ZZ';

-- Ensure one canonical ZZ row exists and is named
INSERT INTO countries(name, iso2, created_at, updated_at)
SELECT 'International', 'ZZ', now(), now()
WHERE NOT EXISTS (SELECT 1 FROM countries WHERE iso2='ZZ');
UPDATE countries SET name='International' WHERE iso2='ZZ';
SQL

echo "==> Done. Now re-run your Carriers import (Auto + Clear existing)."
