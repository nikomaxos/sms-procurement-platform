#!/usr/bin/env bash
set -Eeuo pipefail
nav="resources/views/layouts/navigation.blade.php"
[[ -f "$nav" ]] || { echo "[x] $nav not found"; exit 1; }
cp -n "$nav" "$nav.bak.$(date +%F_%H%M%S)" 2>/dev/null || true

# Normalize any broken Settings labels to {{ __('Settings') }}
# 1) {{ __(Settings) }}    -> {{ __('Settings') }}
# 2) {{ __(''Settings'') }} -> {{ __('Settings') }}
sed -i -E \
  -e "s/\{\{\s*__\(\s*Settings\s*\)\s*\}\}/{{ __('Settings') }}/g" \
  -e "s/\{\{\s*__\(\s*''Settings''\s*\)\s*\}\}/{{ __('Settings') }}/g" \
  "$nav"

# Also normalize responsive variant if it was broken there too
sed -i -E \
  -e "s/<x-responsive-nav-link :href=\"route\('settings.index'\)\"[^>]*>\s*\{\{\s*__\(\s*Settings\s*\)\s*\}\}\s*<\/x-responsive-nav-link>/<x-responsive-nav-link :href=\"route('settings.index')\" :active=\"request()->routeIs('settings.*')\">{{ __('Settings') }}<\/x-responsive-nav-link>/g" \
  "$nav"

# Clear caches (Docker-aware)
if docker compose ps app >/dev/null 2>&1; then
  docker compose exec -T app php artisan view:clear
  docker compose exec -T app php artisan route:clear
  docker compose exec -T app php artisan config:clear
  docker compose restart app web >/dev/null
else
  php artisan view:clear
  php artisan route:clear
  php artisan config:clear
fi

echo "[+] Fixed navbar label. Reload /dashboard and /settings."
