#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/make_release_tag_${TS}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Running ${SCRIPT_NAME} at ${TS}"
echo "ROOT_DIR: $ROOT_DIR"
echo "LOG_FILE: $LOG_FILE"

cd "$ROOT_DIR"

TAG_NAME="${1:-}"
TAG_MESSAGE="${2:-}"

if [ -z "$TAG_NAME" ]; then
  echo "Usage: $SCRIPT_NAME <tag-name> [tag-message]"
  echo "Example: $SCRIPT_NAME v0.2-countries-networks-ui \"Countries & Networks UI release\""
  exit 1
fi

if [ -z "$TAG_MESSAGE" ]; then
  TAG_MESSAGE="$TAG_NAME"
fi

if [ ! -d ".git" ]; then
  echo "ERROR: .git directory not found in $ROOT_DIR. Is this a git repo?"
  exit 1
fi

REMOTE_URL="$(git config --get remote.origin.url || true)"
if [ -z "$REMOTE_URL" ]; then
  echo "ERROR: No remote 'origin' configured. Aborting."
  exit 1
fi

echo "==> Remote origin: $REMOTE_URL"

STATUS="$(git status --porcelain=v1 || true)"
if [ -n "$STATUS" ]; then
  echo "ERROR: Working tree is not clean. Commit or stash changes before tagging."
  exit 1
fi

if git tag --list "$TAG_NAME" | grep -qx "$TAG_NAME"; then
  echo "ERROR: Tag '$TAG_NAME' already exists locally."
  exit 1
fi

echo "==> Current HEAD: $(git rev-parse --short HEAD)"
echo "==> Creating annotated tag '$TAG_NAME' with message: $TAG_MESSAGE"

git tag -a "$TAG_NAME" -m "$TAG_MESSAGE"

echo "==> Pushing tag '$TAG_NAME' to origin"
git push origin "$TAG_NAME"

echo "==> Done. Tag created and pushed."
echo "Log file: $LOG_FILE"
