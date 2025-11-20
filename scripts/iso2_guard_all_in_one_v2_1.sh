#!/usr/bin/env bash
# v2.1 — same logic as v2, but self-test won't violate unique(iso2)
set -u -o pipefail

if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
LOGDIR="logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/iso2_guard_$(date +%F_%H-%M-%S).log"

info(){ printf "\n==> %s\n" "$*" | tee -a "$LOG"; }
fail(){ printf "\n[ERROR] %s\n" "$*" | tee -a "$LOG"; }
ok(){ printf "[OK] %s\n" "$*" | tee -a "$LOG"; }

run_psql() {
  stdbuf -oL -eL $DC exec -T postgres psql -X -v ON_ERROR_STOP=1 -P pager=off -U app -d app -f - 2>&1 | tee -a "$LOG"
  return ${PIPESTATUS[0]}
}

status=0
info "[DB] Install ISO2 guard, normalize data, enforce invariants"

run_psql <<'SQL'
BEGIN;

-- Allow up to 3 chars so 'n/a' reaches trigger safely (content enforced later)
ALTER TABLE countries
  ALTER COLUMN iso2 TYPE varchar(3);

-- BEFORE trigger: normalize or coerce to 'ZZ'
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

-- Normalize existing rows
UPDATE countries SET iso2 = UPPER(iso2);
UPDATE countries
   SET iso2 = 'ZZ'
 WHERE iso2 IS NULL
    OR iso2 !~ '^[A-Z]{2}$';

-- Deduplicate by iso2; keep lowest id; relink networks
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

-- Strict CHECK and unique index
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
  ADD CONSTRAINT countries_iso2_check
  CHECK (iso2 ~ '^[A-Z]{2}$');

CREATE UNIQUE INDEX IF NOT EXISTS countries_iso2_unique_idx ON countries(iso2);

-- Friendly ZZ label
UPDATE countries SET name='International' WHERE iso2='ZZ';

COMMIT;

-- ===== SAFE SELF-TEST (no data change) =====
BEGIN;
WITH ins AS (
  INSERT INTO countries(name, iso2, created_at, updated_at)
  VALUES ('__TEST__', 'n/a', now(), now())
  -- no-op update to avoid duplicate error; still RETURNING a row
  ON CONFLICT (iso2) DO UPDATE SET iso2 = countries.iso2
  RETURNING iso2
)
SELECT 'Self-test stored iso2='||iso2 AS result FROM ins;
ROLLBACK;

-- ===== REPORT =====
\echo
\echo === REPORT ===
SELECT COUNT(*) AS countries FROM countries;
SELECT COUNT(*) AS networks  FROM networks;
SELECT id, name, iso2 FROM countries WHERE iso2='ZZ' LIMIT 1;
SELECT id, name, iso2 FROM countries WHERE iso2 IS NULL OR iso2 !~ '^[A-Z]{2}$' LIMIT 5;
SQL

if [ $? -ne 0 ]; then
  fail "Database step failed. See log: $LOG"
  status=1
else
  ok "Database guard + normalize completed"
fi

printf "\nLog saved to: %s\n" "$LOG"
exit $status
