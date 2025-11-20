#!/usr/bin/env bash
set -Eeuo pipefail
# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Ensure .env & APP_KEY (with fallback) + rebuild caches"
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  cd /var/www/html

  # 1) Ensure .env
  if [ ! -f .env ]; then
    cp .env.example .env 2>/dev/null || touch .env
    echo "   - created .env"
  fi

  # 2) Ensure APP_KEY line exists
  if ! grep -q "^APP_KEY=" .env; then
    printf "\nAPP_KEY=\n" >> .env
    echo "   - appended APP_KEY="
  fi

  cur="$(grep -E "^APP_KEY=" .env | cut -d= -f2-)"
  if [ -z "$cur" ]; then
    echo "   - generating APP_KEY (artisan, then fallback if needed)"
    if ! php artisan key:generate --force >/dev/null 2>&1; then
      gen="$(php -r '"'"'try{$k=random_bytes(32);}catch(Exception $e){$k=openssl_random_pseudo_bytes(32);} echo "base64:".base64_encode($k);'"'"')" 
      # replace (even if empty) the APP_KEY line
      sed -i -E "s#^APP_KEY=.*#APP_KEY=${gen}#g" .env
      echo "   - set APP_KEY via fallback"
    fi
  fi

  echo "   - APP_KEY present: $(grep -E "^APP_KEY=" .env | awk -F= "{print length(\$2)>0?\"YES\":\"NO\"}")"

  # 3) perms
  mkdir -p storage/framework/{cache,sessions,views}
  chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
  chmod -R ug+rwX storage bootstrap/cache || true

  # 4) clear & rebuild caches
  php artisan optimize:clear
  php artisan config:clear
  php artisan route:cache
  php artisan view:cache
  php artisan config:cache

  # 5) show a quick health ping
  php -r "echo \"OK: \".(file_exists('.env') && getenv('APP_KEY') ? 'env_loaded' : 'check_docker_env_loading'), PHP_EOL;"
'
echo "==> Done. Visit /healthz then a normal page."
