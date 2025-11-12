#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
remote_url="$(git config --get remote.origin.url || true)"

echo "==> Repo: $root"
echo "==> Branch: $branch"
[ -n "$remote_url" ] && echo "==> Remote: $remote_url"

# Safety: never push a tracked .env by mistake
if git ls-files --error-unmatch .env >/dev/null 2>&1; then
  echo "Refusing to push: '.env' is tracked. Untrack it first:" >&2
  echo "  git rm --cached .env && echo '/.env' >> .gitignore && git add .gitignore" >&2
  exit 1
fi

echo "==> Status (pre-commit):"
git status --porcelain=v1

# Stage everything that isn't ignored
git add -A

# Create commit only if there are staged changes
if git diff --cached --quiet; then
  echo "==> Nothing to commit."
  msg=""
else
  msg="${MSG:-"Chore: remove settings hub & UI fixes [$(date +%F_%H-%M-%S)]"}"
  git commit -m "$msg"
fi

# Rebase on remote branch (best effort)
git pull --rebase origin "$branch" || true

# Push branch
git push origin "$branch"

# Optional tag: pass TAG=1 to enable, or TAG=v1.2.3 for custom
if [ -n "${TAG:-}" ]; then
  tag_val="${TAG}"
  if [ "$TAG" = "1" ]; then
    tag_val="v$(date +%Y%m%d-%H%M)"
  fi
  git tag -a "$tag_val" -m "${msg:-"snapshot $(date)"}" || true
  git push origin "$tag_val" || true
  echo "==> Pushed tag: $tag_val"
fi

echo "==> Done. Pushed '$branch' to $(git config --get remote.origin.url)"
