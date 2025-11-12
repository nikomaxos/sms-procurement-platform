#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

echo "==> Normalize ignores for env files"
grep -qxF '/.env' .gitignore || echo '/.env' >> .gitignore
grep -qxF '/.env.bak.*' .gitignore || echo '/.env.bak.*' >> .gitignore
grep -qxF '/.env.docker' .gitignore || echo '/.env.docker' >> .gitignore
grep -qxF '!.env.example' .gitignore || echo '!.env.example' >> .gitignore

echo "==> Move legacy backups out of PSR-4 path (stops Composer warning)"
if [ -d app/Http/Controllers/_legacy ]; then
  mkdir -p storage/_legacy
  # try git mv if tracked; fall back to mv
  git mv app/Http/Controllers/_legacy "storage/_legacy/controllers_$ts" 2>/dev/null || \
  mv -f app/Http/Controllers/_legacy "storage/_legacy/controllers_$ts"
fi

echo "==> (Optional) Mark repo safe inside container to silence 'dubious ownership'"
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app bash -lc 'git config --global --add safe.directory /var/www/html || true' || true

echo "==> Show what will be committed"
git status --porcelain

echo "==> Stage and commit"
git add -A
git commit -m "Feat: Drop Down Menus — menus, items, drag reorder [${ts}]"

echo "==> Push main"
git pull --rebase origin main || true
git push origin main

echo "==> Create annotated tag and push tags"
TAG="drop-down-menus-working-$(date +%Y%m%d_%H%M%S)"
git tag -a "$TAG" -m " Drop Down Menus Working"
git push origin "$TAG"

echo "==> Done. Tag: $TAG"
