#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
tag="pre-step0_${ts}"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Commit only if there are changes (won’t fail if clean)
  if ! git diff --quiet || ! git diff --cached --quiet; then
    git add -A
    git commit -m "Baseline snapshot before step plan [${ts}]" || true
  fi
  git tag -a "${tag}" -m "Baseline before step plan" || true
  git branch -f cn-fixes-stepwise
  echo "Created tag: ${tag}"
  echo "Created/updated branch (not checked out): cn-fixes-stepwise"
  echo "To switch later:  git switch cn-fixes-stepwise"
  echo "Rollback (safe):  git switch -c rescue_from_baseline ${tag}"
else
  echo "Not a git repo; skipping."
fi
