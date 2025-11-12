#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

# --- 0) Ownership/perms (needs sudo if previous runs used sudo) ---
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
  OWNER="$SUDO_USER"
else
  OWNER="$USER"
fi

# Try to ensure we own the repo; if not, suggest sudo re-run
if ! touch .ownership_probe 2>/dev/null; then
  echo "Repo not writable by $USER. Re-run with: sudo bash scripts/finalize_and_push_dropdowns.sh" >&2
  exit 1
fi
rm -f .ownership_probe

# Ensure writable storage/bootstrap (Blade cache, etc.)
chmod -R u+rwX,go+rX storage bootstrap 2>/dev/null || true
find storage bootstrap -type d -exec chmod 775 {} \; 2>/dev/null || true

# --- 1) .gitignore hygiene (keep .env.example, ignore real envs) ---
grep -qxF '/.env' .gitignore || echo '/.env' >> .gitignore
grep -qxF '/.env.bak.*' .gitignore || echo '/.env.bak.*' >> .gitignore
grep -qxF '/.env.docker' .gitignore || echo '/.env.docker' >> .gitignore
grep -qxF '!.env.example' .gitignore || echo '!.env.example' >> .gitignore

# --- 2) Move legacy controller backups out of PSR-4 path ---
if [ -d app/Http/Controllers/_legacy ]; then
  mkdir -p storage/_legacy
  git mv app/Http/Controllers/_legacy "storage/_legacy/controllers_$ts" 2>/dev/null || \
  mv -f app/Http/Controllers/_legacy "storage/_legacy/controllers_$ts"
fi

# --- 3) Git identity (repo-local) ---
if ! git config --get user.name >/dev/null; then
  git config user.name "Nick"
fi
if ! git config --get user.email >/dev/null; then
  # [Inference] uses your GitHub username-based noreply; change if you prefer a different email
  git config user.email "nikomaxos@users.noreply.github.com"
fi

# --- 4) Silence 'dubious ownership' in the container git (optional) ---
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app bash -lc 'git config --global --add safe.directory /var/www/html || true' || true

# --- 5) Commit & push ---
echo "==> Git status:"
git status --porcelain

git add -A
git commit -m "Feat: Drop Down Menus — menus, items, drag reorder [${ts}]" || echo "Nothing to commit."

git pull --rebase origin main || true
git push origin main

# --- 6) Tag with the exact release note text and push tag ---
TAG="drop-down-menus-working-$(date +%Y%m%d_%H%M%S)"
git tag -a "$TAG" -m " Drop Down Menus Working" || true
git push origin "$TAG" || true

echo "==> Done. Tag: $TAG"
