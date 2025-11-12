#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "==> Normalize ignores for env files"
grep -qxF '/.env' .gitignore || echo '/.env' >> .gitignore
grep -qxF '/.env.bak.*' .gitignore || echo '/.env.bak.*' >> .gitignore
grep -qxF '/.env.docker' .gitignore || echo '/.env.docker' >> .gitignore
grep -qxF '!.env.example' .gitignore || echo '!.env.example' >> .gitignore

echo "==> Move legacy backups out of PSR-4 path (stops Composer warning)"
if [ -d app/Http/Controllers/_legacy ]; then
  mkdir -p storage/_legacy
  git mv app/Http/Controllers/_legacy "storage/_legacy/controllers_$ts" 2>/dev/null || \
  mv -f app/Http/Controllers/_legacy "storage/_legacy/controllers_$ts"
fi

echo "==> (Optional) Mark repo safe inside container to silence 'dubious ownership'"
$DC exec -T app bash -lc 'git config --global --add safe.directory /var/www/html || true' >/dev/null 2>&1 || true

echo "==> Ensure local git identity"
name="$(git config user.name || true)"
email="$(git config user.email || true)"
if [ -z "$name" ] || [ -z "$email" ]; then
  git config user.name  "Nick"
  git config user.email "nick@local"
  echo "   -> set repo-local identity: Nick <nick@local>"
fi

echo "==> Show what will be committed"
git status --porcelain

echo "==> Stage & commit"
git add -A

# If nothing to commit, exit cleanly
if git diff --cached --quiet; then
  echo "   -> nothing to commit."
else
  git commit -m "Feat: IMAP Settings UI (test/fetch without save, folder tree labels, polling log)
Fix: button styles & Blade/cache perms
Feat: Dropdown items drag-reorder"
fi

echo "==> Push main"
git rev-parse --verify main >/dev/null 2>&1 || git branch -M main
git pull --rebase origin main 2>/dev/null || true
git push -u origin main

echo "==> Tag release"
TAG="imap-settings-ui_$(date +%Y%m%d_%H%M%S)"
git tag -a "$TAG" -m "IMAP Settings UI & Dropdown reorder — ${ts}"
git push origin "$TAG"

echo "==> Done. Last commit:"
git --no-pager log -1 --stat
