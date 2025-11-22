#!/usr/bin/env bash
set -euo pipefail

##
# push_everything_v1.sh
#
# Stages all changes, commits (if needed), pulls with rebase, and pushes to origin/main.
# Usage:
#   ./scripts/push_everything_v1.sh "your commit message"
# If no message is given, a generic timestamped one is used.
##

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
  pwd
)"
cd "$ROOT_DIR"

BRANCH="main"
DEFAULT_MSG="chore: sync changes $(date +%F_%H-%M-%S)"
COMMIT_MSG="${1:-$DEFAULT_MSG}"

echo "==> Working directory: ${ROOT_DIR}"
echo "==> Using branch: ${BRANCH}"
echo "==> Commit message: ${COMMIT_MSG}"

echo "==> Git status (before):"
git status

echo "==> Staging all changes..."
git add -A

if git diff --cached --quiet; then
  echo "==> No staged changes to commit; skipping commit."
else
  echo "==> Committing..."
  git commit -m "${COMMIT_MSG}"
fi

echo "==> Pull --rebase from origin/${BRANCH} (ignore failure if conflicts or no remote)..."
git pull --rebase origin "${BRANCH}" || echo "   (pull --rebase failed or not needed; continuing)"

echo "==> Pushing to origin/${BRANCH}..."
git push origin "${BRANCH}"

echo "==> Done."
git status
