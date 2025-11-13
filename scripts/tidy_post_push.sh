# scripts/tidy_post_push.sh
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

# 1) Remove the stray file if present
rm -f "AppHttpMiddlewareAdminMiddleware::class," || true

# 2) Deduplicate the second 'settings/dropdowns' route group
f="routes/web.php"
cp -a "$f" "$f.bak.$(date +%F_%H-%M-%S)"
awk '
  BEGIN{skip=0; depth=0; seen=0}
  /Route::middleware\(\x27?\\\[?\x27?auth\x27?\x5D?\x27?\)\.prefix\(\x27settings\/dropdowns\x27\)\.name\(\x27settings\.dropdowns\.\x27\)\.group\(function \(\) \{/ {
    seen++;
    if (seen==2) { skip=1 }
  }
  {
    if (skip) {
      # track braces while skipping
      oc = gsub(/\{/,"{"); cc = gsub(/\}/,"}");
      depth += oc - cc;
      if (depth<=0 && /\}\);\s*$/) { skip=0; depth=0; next }
      next
    }
    print
  }
' "$f" > "$f.tmp" && mv "$f.tmp" "$f"

# 3) Optional: stop committing backup files
grep -qxF '*.bak.*' .gitignore || echo '*.bak.*' >> .gitignore

# 4) Rebuild route cache in the container
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan route:cache'

# 5) Commit + push
git add -A
if ! git diff --cached --quiet; then
  git commit -m "Tidy: remove stray file + dedupe dropdown routes + ignore *.bak.*"
  git push
fi
echo "Done."
