#!/usr/bin/env bash
set -Eeuo pipefail

# Detect docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

uid="$(id -u)"; gid="$(id -g)"

echo "==> Fix git DB ownership (may ask for sudo once)"
if command -v sudo >/dev/null 2>&1; then
  sudo chown -R "$uid:$gid" .git 2>/dev/null || true
  # also fix any root-owned files that block staging
  sudo chown -R "$uid:$gid" . 2>/dev/null || true
else
  chown -R "$uid:$gid" .git 2>/dev/null || true
  chown -R "$uid:$gid" . 2>/dev/null || true
fi
chmod -R u+rwX,g+rwX,o-rwx .git 2>/dev/null || true

echo "==> Mark repo safe inside container (prevents 'dubious ownership')"
$DC exec -T app bash -lc 'git config --global --add safe.directory /var/www/html || true' || true

echo "==> Move legacy PSR-4 breakers out of app/ (if present)"
if [ -d app/Http/Controllers/_legacy ]; then
  mkdir -p storage/_legacy
  ts="$(date +%F_%H-%M-%S)"
  git mv app/Http/Controllers/_legacy "storage/_legacy/controllers_$ts" 2>/dev/null || \
  mv -f app/Http/Controllers/_legacy "storage/_legacy/controllers_$ts"
fi

echo "==> Normalize ignore list"
touch .gitignore
grep -qxF '/.env' .gitignore || echo '/.env' >> .gitignore
grep -qxF '/.env.bak.*' .gitignore || echo '/.env.bak.*' >> .gitignore
grep -qxF '/.env.docker' .gitignore || echo '/.env.docker' >> .gitignore
grep -qxF '!.env.example' .gitignore || echo '!.env.example' >> .gitignore
grep -qxF 'storage/_legacy/' .gitignore || echo 'storage/_legacy/' >> .gitignore
grep -qxF 'routes/*.bak.*' .gitignore || echo 'routes/*.bak.*' >> .gitignore
grep -qxF 'database/migrations/_bak/' .gitignore || echo 'database/migrations/_bak/' >> .gitignore
grep -qxF '/vendor/' .gitignore || echo '/vendor/' >> .gitignore
grep -qxF '/node_modules/' .gitignore || echo '/node_modules/' >> .gitignore
grep -qxF '/public/hot' .gitignore || echo '/public/hot' >> .gitignore
grep -qxF '/public/storage' .gitignore || echo '/public/storage' >> .gitignore

echo "==> Ensure scripts are executable"
find scripts -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

echo "==> Repo-scoped identity (avoid 'identity unknown')"
git config user.name  >/dev/null || git config user.name  "Nick"
git config user.email >/dev/null || git config user.email "nick@local.invalid"

echo "==> Stage & commit"
git add -A
if git diff --cached --quiet; then
  echo "Nothing to commit."
else
  git commit -m "Drop Down Menus Working"
fi

echo "==> Push"
if git remote get-url origin >/dev/null 2>&1; then
  git pull --rebase origin main || true
  git push origin main || true
  tag="drop-down-menus-working-$(date +%Y%m%d_%H%M%S)"
  git tag -a "$tag" -m "Drop Down Menus Working"
  git push origin "$tag" || true
  echo "==> Done. Tag: $tag"
else
  echo "==> No 'origin' remote set. Add it and re-run:"
  echo "   git remote add origin <YOUR_GIT_URL>"
fi
