#!/usr/bin/env bash
set -Eeuo pipefail

branch=${1:-main}
remote=${2:-origin}
repo=${3:-https://github.com/nikomaxos/sms-procurement-platform.git}

# sensible ignores
cat > .gitignore <<'GIT'
/vendor/
/node_modules/
/storage/*.key
/.idea/
/.vscode/
/public/build/
/backup_*.tgz
/.backup_before_*
GIT

git init -b "$branch" 2>/dev/null || true
git add -A
git commit -m "Containerized baseline: app/web/postgres + bootstrap + seeds" || true

if git remote get-url "$remote" >/dev/null 2>&1; then
  echo "[i] Remote '$remote' exists → $(git remote get-url "$remote")"
else
  git remote add "$remote" "$repo"
fi

# set default upstream if not set
git push -u "$remote" "$branch"
git tag -f v0.1.0
git push -f "$remote" v0.1.0
echo "✅ Pushed branch '$branch' and tag v0.1.0"
