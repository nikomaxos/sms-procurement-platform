#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Verify base table constraints and run a safe smoke test"

$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
-- Ensure base table has CHECK + UNIQUE, then do a safe insert test
DO $$
DECLARE is_view boolean;
DECLARE base_tbl text;
BEGIN
  SELECT (relkind='v') INTO is_view
  FROM pg_class WHERE oid = to_regclass('public.countries');

  base_tbl := CASE WHEN is_view THEN 'countries_base' ELSE 'countries' END;

  -- Re-assert strict CHECK and UNIQUE on base table (iso2 two letters)
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = base_tbl::regclass AND conname='countries_iso2_check') THEN
    EXECUTE format('ALTER TABLE %I DROP CONSTRAINT countries_iso2_check', base_tbl);
  END IF;
  EXECUTE format('ALTER TABLE %I ADD CONSTRAINT countries_iso2_check CHECK (iso2 ~ ''^[A-Z]{2}$'')', base_tbl);
  EXECUTE format('CREATE UNIQUE INDEX IF NOT EXISTS countries_iso2_unique_idx ON %I(iso2)', base_tbl);
END$$;

-- Smoke test: if countries is a view, plain INSERT (view trigger upserts to base),
-- else do table INSERT ... ON CONFLICT
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='countries') THEN
    INSERT INTO countries(name, iso2, created_at, updated_at)
    VALUES ('International Networks','n/a', now(), now());
  ELSE
    INSERT INTO countries(name, iso2, created_at, updated_at)
    VALUES ('International Networks','n/a', now(), now())
    ON CONFLICT (iso2) DO NOTHING;
  END IF;
END$$;

\echo === REPORT ===
SELECT COUNT(*) AS countries FROM countries;
SELECT id, name, iso2 FROM countries WHERE iso2='ZZ' ORDER BY id LIMIT 1;
SQL
