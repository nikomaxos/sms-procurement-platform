#!/usr/bin/env bash
set -Eeuo pipefail

ts="$(date +%F_%H-%M-%S)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

echo "==> Normalize .gitignore (idempotent)"
add_ignore() { grep -qxF "$1" .gitignore || echo "$1" >> .gitignore; }
touch .gitignore
add_ignore '/.env'
add_ignore '/.env.bak.*'
add_ignore '/.env.docker'
add_ignore '!.env.example'
add_ignore 'storage/_legacy/'
add_ignore 'routes/*.bak.*'
add_ignore 'database/migrations/_bak/'
add_ignore '/vendor/'
add_ignore '/node_modules/'
add_ignore '/public/hot'
add_ignore '/public/storage'

echo "==> Move legacy PSR-4 breakers out of app/ to storage/_legacy (no composer warnings)"
src_legacy="app/Http/Controllers/_legacy"
dst_legacy="storage/_legacy/controllers_$ts"
if [ -d "$src_legacy" ]; then
  mkdir -p "storage/_legacy"
  git mv "$src_legacy" "$dst_legacy" 2>/dev/null || mv -f "$src_legacy" "$dst_legacy" 2>/dev/null || sudo mv -f "$src_legacy" "$dst_legacy" || true
fi

echo "==> Mark repo safe inside container (stops 'dubious ownership')"
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app bash -lc 'git config --global --add safe.directory /var/www/html || true' || true

echo "==> Ensure local git identity (repo-scoped)"
if ! git config user.name >/dev/null; then git config user.name "Nick"; fi
if ! git config user.email >/dev/null; then git config user.email "nick@local.invalid"; fi

echo "==> Show pending changes"
git status --porcelain

echo "==> Stage & commit"
git add -A

msg="Feat: IMAP & Dropdowns — test/fetch without save, hierarchical folder labels, last_run_at box; dropdown menus + items + drag-reorder; admin-only users management hidden; topbar/menu UX fixes [${ts}]"
if ! git diff --cached --quiet; then
  git commit -m "$msg"
else
  echo "==> Nothing to commit (working tree clean)"
fi

echo "==> Push (if 'origin' exists)"
if git remote get-url origin >/dev/null 2>&1; then
  git pull --rebase origin main || true
  git push origin main || true
  tag="release-$(date +%Y%m%d_%H%M%S)"
  git tag -a "$tag" -m "Release: IMAP & Dropdowns stable"
  git push origin "$tag" || true
  echo "==> Pushed. Tag: $tag"
else
  echo "==> No 'origin' remote found. Add it then re-run:"
  echo "   git remote add origin <YOUR_GIT_URL>"
fi
