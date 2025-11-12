#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="${HOME}/sms-procurement-platform"
REMOTE="origin"

cd "$REPO_DIR"

# Use current branch or create main if HEAD-detached
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
if [ "$branch" = "HEAD" ] || [ -z "$branch" ]; then
  branch="main"
  git checkout -B "$branch"
fi

# Stage the feature files (controller, routes, views, scripts)
git add \
  app/Http/Controllers/Auth/PasswordChangeController.php \
  resources/views/auth/password-change.blade.php \
  resources/views/partials/topbar.blade.php \
  resources/views/partials/sidebar.blade.php \
  resources/views/layouts/app.blade.php \
  routes/web.php \
  scripts/*.sh 2>/dev/null || true

# Also include modifications to already-tracked files (but not new ignored files)
git add -u

stamp="$(date +%F_%H-%M-%S)"
msg="UI: left sidebar + hover Settings; top-right user menu + Change Password flow [${stamp}]"

if git diff --cached --quiet; then
  echo "==> No changes staged; nothing to push."
else
  git commit -m "$msg"
fi

git pull --rebase "$REMOTE" "$branch" || true
git push "$REMOTE" "$branch"
echo "==> Pushed to $(git remote get-url "$REMOTE") ($branch)"
