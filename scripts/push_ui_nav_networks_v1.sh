#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/push_ui_nav_networks_${TS}.log"

# Log everything to file + stdout
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Running ${SCRIPT_NAME} at ${TS}"
echo "ROOT_DIR: $ROOT_DIR"
echo "LOG_FILE: $LOG_FILE"

cd "$ROOT_DIR"

# Safety checks
if [ ! -d ".git" ]; then
  echo "ERROR: .git directory not found in $ROOT_DIR. Is this a git repo?"
  exit 1
fi

REMOTE_URL="$(git config --get remote.origin.url || true)"
if [ -z "$REMOTE_URL" ]; then
  echo "ERROR: No remote 'origin' configured. Aborting."
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD || echo 'main')"
echo "==> Current branch: $BRANCH"
echo "==> Remote origin: $REMOTE_URL"

# Detect changes
CHANGES="$(git status --porcelain=v1 || true)"
if [ -z "$CHANGES" ]; then
  echo "==> No local changes to commit. Nothing to push."
  exit 0
fi

echo "==> Changes to be committed:"
git status

# Stage everything
echo "==> Staging all changes (git add .)"
git add .

# Commit
COMMIT_MSG="ui(nav,networks): settings dropdown, carriers import link, horizontal filters"
echo "==> Committing with message: ${COMMIT_MSG}"
git commit -m "${COMMIT_MSG}"

# Tag with timestamp
TAG="ui-nav-networks-${TS}"
echo "==> Tagging current commit as: ${TAG}"
git tag "${TAG}"

# Push branch
echo "==> Pushing branch '${BRANCH}' to origin"
git push origin "${BRANCH}"

# Push tag
echo "==> Pushing tag '${TAG}' to origin"
git push origin "${TAG}"

echo "==> Done. Changes and tag have been pushed."
echo "Log file: $LOG_FILE"
