#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"

# Compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
SERVICE="${SERVICE:-app}"

# yq v4 helper
yq4(){ docker run --rm -v "$PWD":/work -w /work mikefarah/yq:4 "$@"; }

echo "==> [0] Preconditions"
[ -f docker-compose.yml ] || { echo "docker-compose.yml not found"; exit 1; }
docker pull --quiet mikefarah/yq:4 >/dev/null 2>&1 || true

latest_bak(){ ls -1t docker-compose.yml.bak.* 2>/dev/null | head -n1 || true; }

echo "==> [1] Validate base compose; auto-restore if broken"
if ! yq4 -oy '.' docker-compose.yml >/dev/null 2>&1; then
  bak="$(latest_bak)"
  if [ -n "$bak" ]; then
    echo "   - Restoring docker-compose.yml from $bak"
    cp -f "$bak" docker-compose.yml
  else
    echo "   - Still invalid and no backup available."
    nl -ba docker-compose.yml | sed -n '1,80p'
    exit 2
  fi
  # Re-validate after restore
  yq4 -oy '.' docker-compose.yml >/dev/null
fi

echo "==> [2] Ensure host .env has a non-empty APP_KEY"
if [ ! -f .env ]; then cp -f .env.example .env 2>/dev/null || touch .env; echo "   - created .env"; fi
grep -q '^APP_KEY=' .env || { printf "\nAPP_KEY=\n" >> .env; echo "   - appended APP_KEY="; }
APP_KEY_VAL="$(grep -E '^APP_KEY=' .env | cut -d= -f2-)"
if [ -z "$APP_KEY_VAL" ]; then
  APP_KEY_VAL="base64:$(head -c 32 /dev/urandom | base64 | tr -d '\n')"
  sed -i -E "s#^APP_KEY=.*#APP_KEY=${APP_KEY_VAL}#g" .env
  echo "   - generated APP_KEY in host .env"
else
  echo "   - APP_KEY present in host .env"
fi

echo "==> [3] Inject APP_KEY into ${SERVICE}.environment (preserve list/map type)"
# Backup once
cp -a docker-compose.yml docker-compose.yml.bak."$ts"

# Does the service exist?
svc_tag="$(yq4 e '.services[env(SERVICE)] | type' -o=json docker-compose.yml 2>/dev/null || true)"
[ "$svc_tag" = "!!map" ] || { echo "   - Service '$SERVICE' not found in docker-compose.yml"; exit 3; }

env_type="$(yq4 e '.services[env(SERVICE)].environment | type' -o=json docker-compose.yml 2>/dev/null || echo '!!null')"

case "$env_type" in
  "!!seq")
    # Remove any existing APP_KEY=... entries, then append one
    yq4 -i '
      .services[env(SERVICE)].environment
        |= ( ( . // [] )
             | map(select(. | test("^APP_KEY=") | not))
             + ["APP_KEY=${APP_KEY}"] )
    ' docker-compose.yml
    ;;
  "!!map")
    yq4 -i '.services[env(SERVICE)].environment.APP_KEY = "${APP_KEY}"' docker-compose.yml
    ;;
  "!!null")
    # Create a mapping with APP_KEY
    yq4 -i '.services[env(SERVICE)].environment = {"APP_KEY":"${APP_KEY}"}' docker-compose.yml
    ;;
  *)
    echo "   - Unexpected environment node type: $env_type"
    exit 4
    ;;
esac

# Final sanity check
yq4 -oy '.' docker-compose.yml >/dev/null

echo "==> [4] Recreate ${SERVICE} to pick up env"
$DC up -d --force-recreate "$SERVICE"

echo "==> [5] Clear caches and verify config('app.key') inside container"
$DC exec -T "$SERVICE" sh -lc '
  set -Eeuo pipefail
  cd /var/www/html || cd /app || pwd
  echo -n "   - getenv(APP_KEY): "; php -r "echo getenv(\"APP_KEY\")?:\"(empty)\"; echo PHP_EOL;"
  php artisan optimize:clear >/dev/null 2>&1 || true
  php artisan config:clear   >/dev/null 2>&1 || true
  php artisan route:cache    >/dev/null 2>&1 || true
  php artisan view:cache     >/dev/null 2>&1 || true
  php artisan config:cache   >/dev/null 2>&1 || true
  cat > /tmp/check_app_key.php <<PHP
<?php
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap();
echo config('app.key') ? "CFG_OK\\n" : "CFG_MISS\\n";
PHP
  php /tmp/check_app_key.php || true
  rm -f /tmp/check_app_key.php
'
echo "==> Done. Expect CFG_OK. If not, run with a different service:  SERVICE=<your_app_service> bash scripts/compose_inject_app_key_typesafe.sh"
