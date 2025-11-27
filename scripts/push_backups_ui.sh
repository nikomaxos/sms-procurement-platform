#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root (script is in ./scripts/)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/push_backups_ui_$(date +%F_%H-%M-%S).log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Repo root: $ROOT"
echo "==> Log file:  $LOG_FILE"

# Detect current branch (fallback to main)
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
NOTE="Backups working via UI"
TAG_BASE="backups-working-via-ui"
TAG="${TAG_BASE}-$(date +%F_%H-%M-%S)"

echo "==> Using branch: ${BRANCH}"
echo "==> Tag to create: ${TAG}"
echo "==> Tag note: ${NOTE}"

echo "==> Git status (before):"
git status

echo "==> Pulling latest from origin/${BRANCH} (rebase)..."
git pull --rebase origin "${BRANCH}" || true

echo "==> Staging all changes..."
git add -A

if git diff --cached --quiet; then
  echo "==> No staged changes to commit; will only push & tag."
else
  COMMIT_MSG="chore: ${NOTE} [$(date +%F_%H-%M-%S)]"
  echo "==> Committing with message: ${COMMIT_MSG}"
  git commit -m "${COMMIT_MSG}"
fi

echo "==> Pushing branch to origin/${BRANCH}..."
git push origin "${BRANCH}"

echo "==> Creating annotated tag: ${TAG}"
git tag -a "${TAG}" -m "${NOTE}"

echo "==> Pushing tag ${TAG} to origin..."
git push origin "${TAG}"

echo "==> Recent tags:"
git tag --list | tail -n 5

echo "==> Done. Backups UI changes pushed & tagged as ${TAG}"
