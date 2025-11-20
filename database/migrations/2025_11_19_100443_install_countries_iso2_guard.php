<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        DB::unprepared(<<<'SQL'
-- 1) widen so bad inputs can be normalized first
ALTER TABLE countries
  ALTER COLUMN iso2 TYPE varchar(3);

-- 2) trigger to coerce/uppercase ISO2 (invalid -> 'ZZ')
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

-- 3) normalize existing rows
UPDATE countries SET iso2 = 'ZZ'
 WHERE iso2 IS NULL OR iso2 !~ '^[A-Za-z]{2}$';
UPDATE countries SET iso2 = UPPER(iso2);

-- 4) deduplicate by iso2, preserving lowest id; relink networks
DROP TABLE IF EXISTS _dups;
CREATE TEMP TABLE _dups AS
SELECT iso2, MIN(id) AS keep_id, ARRAY_AGG(id) AS ids
FROM countries
GROUP BY iso2
HAVING COUNT(*) > 1;

UPDATE networks n
SET country_id = d.keep_id
FROM _dups d
WHERE n.country_id = ANY(d.ids) AND n.country_id <> d.keep_id;

DELETE FROM countries c
USING _dups d
WHERE c.iso2 = d.iso2 AND c.id <> d.keep_id;

-- 5) enforce strict format & unique key
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
  ALTER COLUMN iso2 TYPE varchar(2)
  USING UPPER(SUBSTRING(iso2 FROM 1 FOR 2)),
  ADD CONSTRAINT countries_iso2_check CHECK (iso2 ~ '^[A-Z]{2}$');

CREATE UNIQUE INDEX IF NOT EXISTS countries_iso2_unique_idx ON countries(iso2);

-- 6) ensure friendly ZZ row exists & is named
INSERT INTO countries(name, iso2, created_at, updated_at)
SELECT 'International','ZZ', now(), now()
WHERE NOT EXISTS (SELECT 1 FROM countries WHERE iso2='ZZ');

UPDATE countries SET name='International' WHERE iso2='ZZ';
SQL);
    }

    public function down(): void {
        DB::unprepared(<<<'SQL'
DROP TRIGGER IF EXISTS trg_countries_iso2_guard ON countries;
DROP FUNCTION IF EXISTS countries_iso2_guard();
ALTER TABLE countries DROP CONSTRAINT IF EXISTS countries_iso2_check;
DROP INDEX IF EXISTS countries_iso2_unique_idx;
-- optional: widen back if you want
ALTER TABLE countries ALTER COLUMN iso2 TYPE varchar(3);
SQL);
    }
};
