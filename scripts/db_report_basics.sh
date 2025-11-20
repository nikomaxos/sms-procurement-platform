#!/usr/bin/env bash
set -euo pipefail
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T postgres psql -U app -d app -v ON_ERROR_STOP=1 <<'SQL'
\echo == COUNTS ==
SELECT COUNT(*) AS countries FROM countries;
SELECT COUNT(*) AS networks  FROM networks;

\echo == ZZ COUNTRY ==
SELECT id, name, iso2 FROM countries WHERE iso2='ZZ';

\echo == BAD ISO2s (should be 0 rows) ==
SELECT id, name, iso2 FROM countries WHERE iso2 IS NULL OR iso2 !~ '^[A-Z]{2}$' LIMIT 5;

\echo == NETWORKS REFERENCING ZZ (sample 10) ==
SELECT n.id, n.name, n.country_id
FROM networks n
JOIN countries c ON c.id = n.country_id
WHERE c.iso2='ZZ'
ORDER BY n.id
LIMIT 10;

\echo == SAMPLE NETWORKS (first 10) ==
SELECT n.id, n.name, n.country_id, c.iso2
FROM networks n
LEFT JOIN countries c ON c.id = n.country_id
ORDER BY n.id
LIMIT 10;
SQL
