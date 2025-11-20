#!/usr/bin/env bash
set -euo pipefail

# compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> 0) Preconditions"
[ -f Dockerfile.rescue ] || { echo "Missing Dockerfile.rescue (from rescue)."; exit 1; }
mkdir -p docker/nginx
[ -f docker/nginx/default.conf ] || {
  cat > docker/nginx/default.conf <<'NGINX'
server {
  listen 80;
  server_name _;
  root /var/www/html/public;
  index index.php index.html;

  location / { try_files $uri $uri/ /index.php?$query_string; }

  location ~ \.php$ {
    include fastcgi_params;
    fastcgi_pass app:9000;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
  }

  client_max_body_size 32m;
  sendfile off;
}
NGINX
}

echo "==> 1) Ensure host .env + APP_KEY"
if [ ! -f .env ]; then cp -f .env.example .env 2>/dev/null || touch .env; echo "   - created .env"; fi
grep -q '^APP_KEY=' .env || { printf "\nAPP_KEY=\n" >> .env; echo "   - appended APP_KEY="; }
if [ -z "$(grep -E '^APP_KEY=' .env | cut -d= -f2-)" ]; then
  sed -i -E "s#^APP_KEY=.*#APP_KEY=base64:$(head -c 32 /dev/urandom | base64 | tr -d '\n')#g" .env
  echo "   - generated APP_KEY in host .env"
fi

echo "==> 2) Stop rescue stack (frees port 8080)"
$DC -f docker-compose.clean.yml down || true

echo "==> 3) Write clean docker-compose.yml (uses the SAME DB volume as rescue)"
# NOTE: Compose auto-prefixes volume with project dir (sms-procurement-platform_dbdata_rescue2).
# Reusing the same name keeps your data.
cat > docker-compose.yml <<'YML'
services:
  postgres:
    image: postgres:15
    container_name: sms-platform-postgres
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
    volumes:
      - dbdata_rescue2:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app -h localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build:
      context: .
      dockerfile: Dockerfile.rescue
    container_name: sms-platform-app
    working_dir: /var/www/html
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      APP_KEY: ${APP_KEY}
      DB_CONNECTION: pgsql
      DB_HOST: postgres
      DB_PORT: 5432
      DB_DATABASE: app
      DB_USERNAME: app
      DB_PASSWORD: secret
    volumes:
      - ./:/var/www/html
      - ./.env:/var/www/html/.env:ro

  web:
    image: nginx:1.27-alpine
    container_name: sms-platform-web
    depends_on:
      - app
    ports:
      - "8080:80"
    volumes:
      - ./:/var/www/html
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro

volumes:
  dbdata_rescue2:
    # Reuse the already-created rescue volume (keeps data)
    name: sms-procurement-platform_dbdata_rescue2
YML

echo "==> 4) Bring main stack up"
$DC up -d --build

echo "==> 5) Finalize app (composer, migrate, caches, verify APP_KEY)"
$DC exec -T app bash -lc '
  set -e
  cd /var/www/html
  if [ ! -d vendor ]; then
    composer install --no-interaction --prefer-dist --optimize-autoloader || composer install --no-interaction --prefer-dist
  fi
  php artisan migrate --force
  php artisan optimize:clear || true
  php artisan config:clear   || true
  php artisan route:clear    || true
  php artisan view:clear     || true
  php artisan config:cache   || true
  php artisan route:cache    || true
  php artisan view:cache     || true
  php -r "require __DIR__.\x27/vendor/autoload.php\x27; \$app=require __DIR__.\x27/bootstrap/app.php\x27; \$app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap(); echo (config(\x27app.key\x27)? \x27CFG_OK\x27 : \x27CFG_MISS\x27), PHP_EOL;"
'

echo "==> 6) Clean orphan old node container (optional)"
docker rm -f sms-platform-node 2>/dev/null || true

echo "==> Done. Open: http://192.168.50.102:8080/healthz  and then /login"
