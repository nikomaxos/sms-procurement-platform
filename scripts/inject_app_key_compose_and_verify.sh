#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> [0] Preconditions"
[ -f docker-compose.yml ] || { echo "docker-compose.yml not found"; exit 1; }

echo "==> [1] Ensure host .env with non-empty APP_KEY"
if [ ! -f .env ]; then cp -f .env.example .env 2>/dev/null || touch .env; echo "   - created .env"; fi
grep -q '^APP_KEY=' .env || { printf "\nAPP_KEY=\n" >> .env; echo "   - appended APP_KEY="; }
cur="$(grep -E '^APP_KEY=' .env | cut -d= -f2-)"
if [ -z "$cur" ]; then
  key="base64:$(head -c 32 /dev/urandom | base64 | tr -d '\n')"
  sed -i -E "s#^APP_KEY=.*#APP_KEY=${key}#g" .env
  echo "   - generated APP_KEY in host .env"
else
  echo "   - APP_KEY already present in host .env"
fi

echo "==> [2] Inject APP_KEY into app service environment (docker-compose.yml)"
b docker-compose.yml
perl -0777 -pe '
  use strict; use warnings;
  my $c = $_;

  # find "app:" service block (same name you exec against)
  my ($pre,$app,$post) = $c =~ m/\A(.*?^\s*app:\s*\n)(.*?)(^\S.*\z|\z)/ms;
  unless (defined $app) { print STDERR "!! Could not locate service \"app:\" in docker-compose.yml\n"; exit 2; }

  # already has environment section?
  if ($app =~ m/^\s*environment:\s*\n/ms) {
      # ensure APP_KEY is present (array or map forms)
      if ($app !~ m/^\s*environment:\s*\n(?:(?:\s*-\s*APP_KEY=)|(?:\s*APP_KEY\s*:\s*))/ms) {
          # add array item by default right after environment:
          $app =~ s/(^\s*environment:\s*\n)/$1$&/; # no-op to get $1
          $app =~ s/(^\s*environment:\s*\n)/$1      - APP_KEY=\${APP_KEY}\n/m;
      }
  } else {
      # insert environment block just after "app:"
      my ($indent) = ($pre =~ m/^(\s*)app:\s*$/m) ? $1 : "";
      my $env = "${indent}  environment:\n${indent}    - APP_KEY=\${APP_KEY}\n";
      $app = $env . $app;
  }

  $_ = $pre.$app.$post;
' -i docker-compose.yml || { echo "!! Failed to patch docker-compose.yml"; exit 2; }

echo "==> [3] Recreate app container to load new env"
$DC up -d --force-recreate app

echo "==> [4] Clear caches and verify inside container"
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  cd /var/www/html || cd /app || pwd
  echo "   - getenv(APP_KEY):"
  php -r "var_export(getenv(\"APP_KEY\")); echo PHP_EOL;"
  php artisan optimize:clear >/dev/null 2>&1 || true
  php artisan config:clear   >/dev/null 2>&1 || true
  php artisan route:cache    >/dev/null 2>&1 || true
  php artisan view:cache     >/dev/null 2>&1 || true
  php artisan config:cache   >/dev/null 2>&1 || true
  cat > /tmp/check_app_key.php <<'"'"'PHP'"'"'
<?php
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
echo config('app.key') ? "CFG_OK\n" : "CFG_MISS\n";
PHP
  php /tmp/check_app_key.php || true
  rm -f /tmp/check_app_key.php
'

echo "==> [5] If CFG_OK printed above, test /healthz and a normal page."
echo "==> [Rollback] To undo compose change: cp docker-compose.yml.bak.$ts docker-compose.yml && $DC up -d --force-recreate app"
