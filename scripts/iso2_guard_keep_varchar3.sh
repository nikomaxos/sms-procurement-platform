#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Keep countries.iso2 at VARCHAR(3), reassert guard + CHECK, and self-test"
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
-- 1) make sure column can accept inputs like 'n/a' so trigger can run
ALTER TABLE countries
  ALTER COLUMN iso2 TYPE varchar(3);

-- 2) (re)install BEFORE trigger to coerce invalid iso2 -> 'ZZ' and uppercase
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

-- 3) remove any old CHECK and add strict format check (two uppercase letters)
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

-- 4) unique index (idempotent)
CREATE UNIQUE INDEX IF NOT EXISTS countries_iso2_unique_idx ON countries(iso2);

-- 5) ensure ZZ row exists and friendly name
INSERT INTO countries(name, iso2, created_at, updated_at)
SELECT 'International','ZZ', now(), now()
WHERE NOT EXISTS (SELECT 1 FROM countries WHERE iso2='ZZ');

UPDATE countries SET name='International' WHERE iso2='ZZ';

-- 6) self-test: try to "insert" n/a; should be coerced to ZZ, then conflict -> DO NOTHING (no error)
INSERT INTO countries(name, iso2, created_at, updated_at)
VALUES ('__TRIGGER_TEST__','n/a', now(), now())
ON CONFLICT (iso2) DO NOTHING;

-- 7) quick report
\echo === REPORT ===
SELECT COUNT(*) AS countries FROM countries;
SELECT COUNT(*) AS networks  FROM networks;
SELECT id,name,iso2 FROM countries WHERE iso2='ZZ';
SQL
