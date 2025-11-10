#!/usr/bin/env bash
set -Eeuo pipefail

echo "[*] Checking docker & compose…"
docker -v >/dev/null
docker compose version >/dev/null

echo "[*] Building containers…"
docker compose build --pull

echo "[*] Starting stack…"
docker compose up -d postgres app web node

echo "[*] Waiting for Postgres health…"
until [ "$(docker inspect -f '{{.State.Health.Status}}' sms-platform-postgres)" = "healthy" ]; do
  sleep 2
  echo -n "."
done
echo

echo "[*] Ensure .env exists inside app (binding .env.docker as .env)"
# already bind-mounted by compose

echo "[*] Generate APP_KEY if missing…"
docker compose exec -T app php -r '
$env=file_get_contents(".env");
if (!preg_match("/^APP_KEY=/m",$env)) { file_put_contents(".env", $env.PHP_EOL."APP_KEY=".PHP_EOL); }
'
docker compose exec -T app php artisan key:generate --force || true

echo "[*] Migrate & seed…"
docker compose exec -T app php artisan migrate --force
docker compose exec -T app php artisan db:seed --force

echo "[*] Build frontend assets (Node service)…"
docker compose exec -T node sh -lc 'npm ci && npm run build'

echo "[*] Clear caches…"
docker compose exec -T app php artisan optimize:clear

echo
echo "✅ Ready: http://localhost:8080"
echo "   Login: admin@example.com / secret (change in Settings → Users)"
