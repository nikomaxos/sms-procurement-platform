#!/usr/bin/env bash
set -Eeuo pipefail

nav="resources/views/layouts/navigation.blade.php"
[[ -f "$nav" ]] || { echo "[x] $nav not found"; exit 1; }
cp -n "$nav" "$nav.bak.$(date +%F_%H%M%S)" 2>/dev/null || true

# 1) Remove any existing Settings links anywhere (so we can reinsert cleanly)
sed -i '/route('\''settings.index'\'')/d' "$nav"

# 2) Insert desktop Settings link right after the Dashboard desktop link
#    (inside: <div class="hidden space-x-8 sm:-my-px sm:ms-10 sm:flex"> … )
sed -i '/<x-nav-link :href="route('\''dashboard'\'')"/a \
@can('\''admin'\'')\
    <x-nav-link :href="route('\''settings.index'\'')" :active="request()->routeIs('\''settings.*'\'')">\
        {{ __(''Settings'') }}\
    </x-nav-link>\
@endcan' "$nav"

# 3) Insert responsive Settings link right after the responsive Dashboard link
sed -i '/<x-responsive-nav-link :href="route('\''dashboard'\'')"/a \
@can('\''admin'\'')\
    <x-responsive-nav-link :href="route('\''settings.index'\'')" :active="request()->routeIs('\''settings.*'\'')">\
        {{ __(''Settings'') }}\
    </x-responsive-nav-link>\
@endcan' "$nav"

# 4) Clear caches (Docker-aware) and restart web stack
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

echo "[+] Navbar normalized. Look for 'Settings' next to 'Dashboard'."
