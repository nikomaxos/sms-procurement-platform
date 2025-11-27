#!/usr/bin/env bash
set -euo pipefail

echo "==> offers_index_guard_vars_v2: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/offers_index_guard_vars_v2_${STAMP}"
echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

INDEX="resources/views/offers/index.blade.php"

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "   - Backing up ${f}"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    cp "$f" "${BACKUP_DIR}/${f}"
  fi
}

backup_file "$INDEX"

if [[ ! -f "$INDEX" ]]; then
  echo "!! $INDEX does not exist, aborting"
  exit 1
fi

# Avoid double-injecting if we already patched once
if grep -q "offers index guard block" "$INDEX"; then
  echo "==> Guard block already present in $INDEX, nothing to do"
  echo "==> offers_index_guard_vars_v2: done"
  exit 0
fi

echo "==> Injecting guard @php block after <x-app-layout> in $INDEX"

TMP_FILE="$(mktemp)"
awk '
  BEGIN { inserted = 0 }
  {
    print $0
    if (!inserted && $0 ~ /<x-app-layout>/) {
      inserted = 1
      print "    {{-- offers index guard block --}}"
      print "    @php"
      print "        $countries        = $countries        ?? collect();"
      print "        $suppliers        = $suppliers        ?? collect();"
      print "        $networks         = $networks         ?? collect();"
      print "        $connections      = $connections      ?? collect();"
      print "        $productTypeItems = $productTypeItems ?? collect();"
      print "        $knownHopsItems   = $knownHopsItems   ?? collect();"
      print "        $senderIdItems    = $senderIdItems    ?? collect();"
      print "        $chargeModels     = $chargeModels     ?? collect();"
      print "    @endphp"
      print ""
    }
  }
' "$INDEX" > "$TMP_FILE"

mv "$TMP_FILE" "$INDEX"

echo "==> offers_index_guard_vars_v2: done"
