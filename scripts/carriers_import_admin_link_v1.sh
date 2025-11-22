#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/carriers_import_admin_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/carriers_import_admin_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR: $ROOT_DIR" | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE" | tee -a "$LOG_FILE"
echo "BACKUP_DIR: $BACKUP_DIR" | tee -a "$LOG_FILE"

# -------------------------------------------------------------------
# Helpers: backup / rollback
# -------------------------------------------------------------------
declare -a MOD_FILES=()
declare -a NEW_FILES=()

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    mkdir -p "$(dirname "$backup_path")" 2>/dev/null || true
    cp "$f" "$backup_path"
    MOD_FILES+=("$f")
    echo "==> Backed up $f -> $backup_path" | tee -a "$LOG_FILE"
  fi
}

rollback() {
  echo "==> Rolling back modified files..." | tee -a "$LOG_FILE"

  for f in "${MOD_FILES[@]}"; do
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    if [ -f "$backup_path" ]; then
      cp "$backup_path" "$f"
      echo "   - Restored $f from $backup_path" | tee -a "$LOG_FILE"
    fi
  done

  for f in "${NEW_FILES[@]}"; do
    if [ -f "$f" ]; then
      rm -f "$f"
      echo "   - Removed new file $f" | tee -a "$LOG_FILE"
    fi
  done
}

on_error() {
  local line="$1"
  echo "ERROR: Failed at line $line in ${SCRIPT_NAME}" | tee -a "$LOG_FILE"
  rollback
  echo "WARN: Rollback complete. Check $LOG_FILE for details." | tee -a "$LOG_FILE"
  exit 1
}

trap 'on_error $LINENO' ERR

# -------------------------------------------------------------------
# Detect app service for artisan
# -------------------------------------------------------------------
APP_SERVICE=""

if command -v docker >/dev/null 2>&1 && command -v docker-compose >/dev/null 2>&1; then
  :
fi

if command -v docker >/dev/null 2>&1; then
  if docker compose ps --services 2>/dev/null | grep -qx "app"; then
    APP_SERVICE="app"
  elif docker compose ps --services 2>/dev/null | grep -qx "sms-platform-app"; then
    APP_SERVICE="sms-platform-app"
  fi
fi

run_artisan() {
  local cmd=("$@")
  if [ -n "$APP_SERVICE" ]; then
    echo "==> [artisan via docker compose exec $APP_SERVICE] ${cmd[*]}" | tee -a "$LOG_FILE"
    docker compose exec -T "$APP_SERVICE" php artisan "${cmd[@]}" | tee -a "$LOG_FILE"
  else
    echo "==> [artisan on host] ${cmd[*]}" | tee -a "$LOG_FILE"
    php artisan "${cmd[@]}" | tee -a "$LOG_FILE"
  fi
}

# -------------------------------------------------------------------
# 1) AdminMiddleware (app/Http/Middleware/AdminMiddleware.php)
# -------------------------------------------------------------------
ADMIN_MW="$ROOT_DIR/app/Http/Middleware/AdminMiddleware.php"

if [ -f "$ADMIN_MW" ]; then
  backup_file "$ADMIN_MW"
else
  NEW_FILES+=("$ADMIN_MW")
fi

cat > "$ADMIN_MW" <<'PHP'
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AdminMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user || $user->usertype !== 'admin') {
            abort(403);
        }

        return $next($request);
    }
}
PHP

echo "==> Wrote AdminMiddleware" | tee -a "$LOG_FILE"

# -------------------------------------------------------------------
# 2) Register 'admin' alias in app/Http/Kernel.php
# -------------------------------------------------------------------
KERNEL="$ROOT_DIR/app/Http/Kernel.php"
if [ -f "$KERNEL" ]; then
  backup_file "$KERNEL"

  if grep -q "AdminMiddleware::class" "$KERNEL"; then
    echo "==> Kernel already references AdminMiddleware; skipping alias injection" | tee -a "$LOG_FILE"
  else
    TMP_K="$KERNEL.tmp.$TS"
    awk 'BEGIN{in_rm=0; done=0}
    {
      if ($0 ~ /protected \$routeMiddleware = \[/) {
        in_rm=1
      }
      if (in_rm && $0 ~ /\];/ && !done) {
        print "        '\''admin'\'' => \\App\\\\Http\\\\Middleware\\\\AdminMiddleware::class,"
        done=1
      }
      print
      if (in_rm && $0 ~ /\];/) {
        in_rm=0
      }
    }' "$KERNEL" > "$TMP_K"

    mv "$TMP_K" "$KERNEL"
    echo "==> Injected 'admin' routeMiddleware alias into Kernel" | tee -a "$LOG_FILE"
  fi
else
  echo "WARN: Kernel.php not found at $KERNEL" | tee -a "$LOG_FILE"
fi

# -------------------------------------------------------------------
# 3) Enforce admin on CarriersImportController (if present)
# -------------------------------------------------------------------
CONTROLLER="$ROOT_DIR/app/Http/Controllers/CarriersImportController.php"
if [ -f "$CONTROLLER" ]; then
  backup_file "$CONTROLLER"

  if grep -q "middleware('admin'" "$CONTROLLER"; then
    echo "==> CarriersImportController already uses admin middleware; skipping" | tee -a "$LOG_FILE"
  else
    if grep -q "function __construct" "$CONTROLLER"; then
      # Insert $this->middleware('admin'); at the top of existing constructor
      perl -0pi -e 's/(function __construct\(\)\s*\{\s*\n)/$1        \$this->middleware('\''admin'\'');\n\n/s' "$CONTROLLER"
      echo "==> Added \$this->middleware('admin') to existing __construct() in CarriersImportController" | tee -a "$LOG_FILE"
    else
      # Add a new constructor under the class opening
      perl -0pi -e 's|(class\s+CarriersImportController[^{]*\{\s*)|$1\n    public function __construct()\n    {\n        \$this->middleware(['\''auth'\'', '\''admin'\'']);\n    }\n\n|s' "$CONTROLLER"
      echo "==> Added __construct() with auth+admin middleware to CarriersImportController" | tee -a "$LOG_FILE"
    fi
  fi
else
  echo "WARN: CarriersImportController.php not found; admin protection only via menu visibility (no controller guard)." | tee -a "$LOG_FILE"
fi

# -------------------------------------------------------------------
# 4) Add "Carriers Import" link for admins in account dropdown
#     resources/views/layouts/navigation.blade.php
# -------------------------------------------------------------------
NAV="$ROOT_DIR/resources/views/layouts/navigation.blade.php"
if [ -f "$NAV" ]; then
  backup_file "$NAV"

  if grep -q "Carriers Import" "$NAV"; then
    echo "==> Navigation already contains 'Carriers Import' label; skipping injection" | tee -a "$LOG_FILE"
  else
    TMP_N="$NAV.tmp.$TS"
    awk 'BEGIN{done=0}
    {
      print
      if (!done && $0 ~ /route\('\''profile.show'\''\)/) {
        print ""
        print "@php($user = \\Illuminate\\Support\\Facades\\Auth::user())"
        print "@if($user && $user->usertype === '\''admin'\'')"
        print "    <x-dropdown-link href=\"{{ route('\''carriers.import'\'') }}\">"
        print "        {{ __('\''Carriers Import'\'') }}"
        print "    </x-dropdown-link>"
        print "@endif"
        done=1
      }
    }' "$NAV" > "$TMP_N"

    mv "$TMP_N" "$NAV"
    echo "==> Injected admin-only 'Carriers Import' link into navigation dropdown" | tee -a "$LOG_FILE"
  fi
else
  echo "WARN: navigation.blade.php not found at $NAV; menu link not added." | tee -a "$LOG_FILE"
fi

# -------------------------------------------------------------------
# 5) Clear & rebuild caches
# -------------------------------------------------------------------
run_artisan optimize:clear
run_artisan view:cache

# -------------------------------------------------------------------
# 6) Git add + commit + tag + push (best-effort)
# -------------------------------------------------------------------
if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "==> Preparing git commit + tag + push" | tee -a "$LOG_FILE"

  cd "$ROOT_DIR"

  GIT_FILES=()
  for f in "$ADMIN_MW" "$KERNEL" "$NAV" "$CONTROLLER"; do
    if [ -f "$f" ]; then
      rel="${f#"$ROOT_DIR/"}"
      GIT_FILES+=("$rel")
    fi
  done

  if [ "${#GIT_FILES[@]}" -gt 0 ]; then
    git add "${GIT_FILES[@]}" | tee -a "$LOG_FILE"
  fi

  if git diff --cached --quiet; then
    echo "==> No staged changes; skipping commit/tag" | tee -a "$LOG_FILE"
  else
    COMMIT_MSG="chore(import): admin-only Carriers Import + menu link"
    TAG_NAME="carriers-import-admin-${TS}"

    git commit -m "$COMMIT_MSG" | tee -a "$LOG_FILE" || echo "WARN: git commit failed" | tee -a "$LOG_FILE"

    if git tag "$TAG_NAME" >/dev/null 2>&1; then
      echo "==> Created tag: $TAG_NAME" | tee -a "$LOG_FILE"
    else
      echo "WARN: Failed to create tag $TAG_NAME (might already exist)" | tee -a "$LOG_FILE"
    fi

    if ! git push origin "$(git rev-parse --abbrev-ref HEAD)" 2>&1 | tee -a "$LOG_FILE"; then
      echo "WARN: git push branch failed (non-fatal)" | tee -a "$LOG_FILE"
    fi
    if ! git push origin "$TAG_NAME" 2>&1 | tee -a "$LOG_FILE"; then
      echo "WARN: git push tag failed (non-fatal)" | tee -a "$LOG_FILE"
    fi
  fi
else
  echo "WARN: Not inside a git repo; skipping commit/tag/push" | tee -a "$LOG_FILE"
fi

echo "==> Script completed successfully." | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Backups stored under: $BACKUP_DIR" | tee -a "$LOG_FILE"
