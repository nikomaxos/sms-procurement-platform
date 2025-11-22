#!/usr/bin/env bash
set -euo pipefail

##
# push_suppliers_connections_v1.sh
#
# Stages all changes, commits, and pushes to origin/main.
# Optional first argument = custom commit message.
##

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BRANCH="${BRANCH:-main}"
DEFAULT_MESSAGE="feat: suppliers connections + product types + connection_dead flag"
COMMIT_MESSAGE="${1:-$DEFAULT_MESSAGE}"

echo "==> Working directory: ${ROOT_DIR}"
echo "==> Target branch: ${BRANCH}"
echo "==> Commit message: ${COMMIT_MESSAGE}"

echo "==> git status (before):"
git status

echo "==> Staging all changes (git add -A)"
git add -A

if git diff --cached --quiet; then
  echo "==> No staged changes to commit. Exiting."
  exit 0
fi

echo "==> Committing..."
git commit -m "${COMMIT_MESSAGE}"

echo "==> Pulling latest from origin/${BRANCH} with rebase (best effort)..."
git pull --rebase origin "${BRANCH}" || echo "==> Warning: git pull --rebase failed (you may need to resolve manually later)."

echo "==> Pushing to origin/${BRANCH}..."
git push origin "${BRANCH}"

echo "==> Done."
git status
