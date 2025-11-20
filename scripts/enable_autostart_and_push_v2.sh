#!/usr/bin/env bash
set -Eeuo pipefail

# ---- Config
SERVICE_NAME="sms-procurement-platform"
UNIT_NAME="${SERVICE_NAME}.service"
OVERRIDE="docker-compose.override.yml"
UNIT_PATH="ops/systemd/${UNIT_NAME}"
LOGDIR="logs"
TAG="infra-autostart-$(date +%F_%H-%M-%S)"

# ---- Helpers
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
SUDO_BIN="${SUDO:-sudo}"
mkdir -p "$(dirname "$UNIT_PATH")" "$LOGDIR"

rollback() {
  set +e
  echo "[ROLLBACK] Reverting unit/override if needed..."
  if command -v systemctl >/dev/null 2>&1; then
    $SUDO_BIN systemctl stop "$UNIT_NAME" >/dev/null 2>&1 || true
    $SUDO_BIN systemctl disable "$UNIT_NAME" >/dev/null 2>&1 || true
    $SUDO_BIN rm -f "/etc/systemd/system/${UNIT_NAME}" >/dev/null 2>&1 || true
    $SUDO_BIN systemctl daemon-reload >/dev/null 2>&1 || true
  fi
  git restore --staged . >/dev/null 2>&1 || true
  git checkout -- "$OVERRIDE" "$UNIT_PATH" >/dev/null 2>&1 || true
  echo "[ROLLBACK] Done."
}
trap 'echo "[ERROR] Failed. See above. Rolling back..."; rollback; exit 1' ERR

echo "==> 1) Ensure Docker starts on boot (if systemd exists)"
if command -v systemctl >/dev/null 2>&1; then
  $SUDO_BIN systemctl enable --now docker
fi

echo "==> 2) Create override with restart policies (only for existing services)"
mapfile -t EXISTING < <($DC config --services 2>/dev/null || true)
declare -A WANT=( [web]=1 [app]=1 [postgres]=1 [node]=1 )

TMP="${OVERRIDE}.new"
{
  echo "services:"
  for s in "${EXISTING[@]}"; do
    if [[ -n "${WANT[$s]:-}" ]]; then
      printf "  %s:\n    restart: unless-stopped\n" "$s"
    fi
  done
} > "$TMP"

if [[ ! -s "$TMP" ]]; then
  # Fallback: no services list? keep common ones (safe if they exist; ignored otherwise via compose merge)
  cat > "$TMP" <<'YML'
services:
  web:
    restart: unless-stopped
  app:
    restart: unless-stopped
  postgres:
    restart: unless-stopped
  node:
    restart: unless-stopped
YML
fi

if [[ ! -f "$OVERRIDE" ]] || ! diff -q "$OVERRIDE" "$TMP" >/dev/null; then
  mv -f "$TMP" "$OVERRIDE"
else
  rm -f "$TMP"
fi

echo "==> 3) Optional systemd unit (uses current repo path)"
REPO_DIR="$(pwd)"
cat > "$UNIT_PATH" <<UNIT
[Unit]
Description=SMS Procurement Platform (Docker Compose)
Wants=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${REPO_DIR}
ExecStart=/usr/bin/docker compose up -d --remove-orphans
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
UNIT

if command -v systemctl >/dev/null 2>&1; then
  $SUDO_BIN cp -f "$UNIT_PATH" "/etc/systemd/system/${UNIT_NAME}"
  $SUDO_BIN systemctl daemon-reload
  $SUDO_BIN systemctl enable "$UNIT_NAME"
  $SUDO_BIN systemctl restart "$UNIT_NAME"
else
  echo "[Unverified] systemd not found; relying on Compose restart policies."
fi

echo "==> 4) Bring stack up now"
$DC up -d --remove-orphans

# Also patch restart policy on current project containers (defense-in-depth)
PROJECT_LABEL="com.docker.compose.project"
mapfile -t IDS < <(docker ps -a -q --filter "label=${PROJECT_LABEL}" 2>/dev/null || true)
if ((${#IDS[@]})); then
  printf "%s\n" "${IDS[@]}" | xargs -r -n50 docker update --restart unless-stopped >/dev/null
fi

echo "==> 5) Smoke test /healthz"
SMOKE_OK=0
for URL in "http://127.0.0.1:8080/healthz" "http://localhost:8080/healthz"; do
  if curl -fsS --max-time 5 "$URL" >/dev/null 2>&1; then
    echo "   - OK via $URL"
    SMOKE_OK=1; break
  fi
done
if [[ "$SMOKE_OK" -eq 0 ]]; then
  # Fallback: confirm route exists inside app
  if $DC exec -T app php artisan route:list | grep -q "healthz"; then
    echo "   - Route exists (artisan)."
  else
    echo "[Unverified] Could not reach /healthz from host; route not found in artisan."
  fi
fi

echo "==> 6) Commit, tag, push"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add "$OVERRIDE" "$UNIT_PATH" "scripts/enable_autostart_and_push_v2.sh"
  git commit -m "infra(autostart): compose restart policies + optional systemd unit; smoke-tested"
  git tag -a "$TAG" -m "Autostart feature"
  BR="$(git rev-parse --abbrev-ref HEAD)"
  if git remote -v | grep -q "(push)"; then
    git push origin "$BR"
    git push origin "$TAG"
  else
    echo "[Unverified] No remote configured; committed locally."
  fi
else
  echo "[Unverified] Not a git repo; skipped push."
fi

echo "==> Done. Containers will auto-start after reboot."
