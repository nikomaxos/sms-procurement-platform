#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="${HOME}/sms-procurement-platform"
REMOTE="origin"
DEFAULT_URL="https://github.com/nikomaxos/sms-procurement-platform.git"  # [Inference]

cd "$REPO_DIR"

# Ensure git repo & remote
if [ ! -d .git ]; then
  git init
  git remote add "$REMOTE" "$DEFAULT_URL" || true
fi

# Protect secrets / heavy dirs
touch .gitignore
ensure_ignored() { local p="$1"; grep -qxF "$p" .gitignore || echo "$p" >> .gitignore; }
ensure_ignored "/.env"
ensure_ignored "/.env.*"
ensure_ignored "/vendor/"
ensure_ignored "/node_modules/"
ensure_ignored "/storage/*.sqlite"
ensure_ignored "/public/storage"

# Untrack if mistakenly committed before
git rm -r --cached --ignore-unmatch .env .env.* vendor node_modules storage/*.sqlite public/storage 2>/dev/null || true

# Stage & commit
git add -A
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
if [ "$branch" = "HEAD" ] || [ -z "$branch" ]; then
  branch="main"
  git checkout -B "$branch"
fi
stamp="$(date +%F_%H-%M-%S)"
msg="Chore: fresh bootstrap & login fix — APP_KEY set, caches refreshed [${stamp}]"

if git diff --cached --quiet; then
  echo "==> No changes to commit."
else
  git commit -m "$msg"
fi

# Ensure remote set
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  git remote add "$REMOTE" "$DEFAULT_URL"
fi

# Push with rebase fallback
set +e
git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1
has_upstream=$?
set -e

if [ $has_upstream -ne 0 ]; then
  git push -u "$REMOTE" "$branch" || { git pull --rebase "$REMOTE" "$branch" || true; git push -u "$REMOTE" "$branch"; }
else
  git pull --rebase "$REMOTE" "$branch" || true
  git push "$REMOTE" "$branch"
fi

echo "==> Pushed '$branch' to $(git remote get-url "$REMOTE")"
