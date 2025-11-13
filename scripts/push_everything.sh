# scripts/push_everything.sh
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

# 1) Ensure git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "==> Initializing repo"
  git init
  git checkout -b main || true
fi

# 2) Sensible ignores (idempotent)
echo "==> Normalizing .gitignore"
grep -qxF '/.env' .gitignore || echo '/.env' >> .gitignore
grep -qxF '/.env.*' .gitignore || echo '/.env.*' >> .gitignore
grep -qxF '!.env.example' .gitignore || echo '!.env.example' >> .gitignore
grep -qxF '/storage/*.log' .gitignore || echo '/storage/*.log' >> .gitignore
grep -qxF '/storage/logs/' .gitignore || echo '/storage/logs/' >> .gitignore
grep -qxF '/vendor/' .gitignore || echo '/vendor/' >> .gitignore
grep -qxF '/node_modules/' .gitignore || echo '/node_modules/' >> .gitignore
grep -qxF '/bootstrap/cache/*' .gitignore || echo '/bootstrap/cache/*' >> .gitignore

# 3) Detect branch & remote
branch="$(git symbolic-ref --quiet --short HEAD || echo main)"
remote_name="origin"
remote_url="$(git remote get-url $remote_name 2>/dev/null || true)"

# 4) Stage & commit
echo "==> Staging all changes"
git add -A

if git diff --cached --quiet; then
  echo "==> Nothing to commit. Will still push and tag if needed."
else
  ts="$(date +%F_%H-%M-%S)"
  echo "==> Committing"
  git commit -m "Snapshot: catalogs + admin-only nav + MCC-MNC filtering + importer + fixes [$ts]"
fi

# 5) Tag
ts_tag="$(date +%Y%m%d_%H%M%S)"
tag="release_catalogs_admin_nav_${ts_tag}"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "==> Tag exists: $tag"
else
  echo "==> Tagging: $tag"
  git tag -a "$tag" -m "Release snapshot $tag"
fi

# 6) Push
if [ -z "$remote_url" ]; then
  echo "==> No remote named 'origin' is set."
  echo "Add one and re-run:"
  echo "  git remote add origin https://github.com/<USER>/<REPO>.git"
  echo "  git push -u origin $branch"
  echo "  git push origin --tags"
  exit 0
fi

echo "==> Pushing to $remote_name/$branch"
git push -u "$remote_name" "$branch"
echo "==> Pushing tags"
git push "$remote_name" --tags

echo "==> Done."
