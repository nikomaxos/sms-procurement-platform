#!/usr/bin/env bash
set -Eeuo pipefail
nav="resources/views/layouts/navigation.blade.php"
[[ -f "$nav" ]] || { echo "[x] $nav not found"; exit 1; }

# Insert inside the Desktop nav block, right after the Dashboard link
if ! grep -q "route('settings.index')" "$nav"; then
  sed -i '/route('"'"'dashboard'"'"')/a\
@can('"'"'admin'"'"')\
    <x-nav-link :href="route('"'"'settings.index'"'"')" :active="request()->routeIs('"'"'settings.*'"'"')">\
        {{ __('"'"'Settings'"'"') }}\
    </x-nav-link>\
@endcan' "$nav"
  echo "[+] Settings link added to desktop nav."
else
  echo "[i] Settings link already present."
fi

# Clear caches (Docker-aware)
if docker compose ps app >/dev/null 2>&1; then
  docker compose exec -T app php artisan route:clear
  docker compose exec -T app php artisan view:clear
  docker compose exec -T app php artisan config:clear
  docker compose restart app web >/dev/null
else
  php artisan route:clear
  php artisan view:clear
  php artisan config:clear
fi
echo "[+] Done."
