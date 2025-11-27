#!/usr/bin/env bash
set -euo pipefail

echo "==> offers_index_fix_vars_and_routes_v1: starting"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/offers_index_fix_vars_and_routes_v1_${STAMP}"
echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

INDEX="resources/views/offers/index.blade.php"
ROUTES="routes/web.php"

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "   - Backing up ${f}"
    mkdir -p "${BACKUP_DIR}/$(dirname "${f}")"
    cp "$f" "${BACKUP_DIR}/${f}"
  fi
}

backup_file "$INDEX"
backup_file "$ROUTES"

# ------------------------------------------------------------------
# 1) Make sure all Blade variables used in the offers index exist
#    ($networks, $connections, $chargeModels, etc.).
#    If controller doesn't pass them, they become empty collections.
# ------------------------------------------------------------------
if [[ -f "$INDEX" ]]; then
  echo "==> Patching $INDEX to define missing collections"

  perl -0pi -e '
    my $block = q{
    @php
        $countries        = $countries        ?? collect();
        $suppliers        = $suppliers        ?? collect();
        $networks         = $networks         ?? collect();
        $connections      = $connections      ?? collect();
        $productTypeItems = $productTypeItems ?? collect();
        $knownHopsItems   = $knownHopsItems   ?? collect();
        $senderIdItems    = $senderIdItems    ?? collect();
        $chargeModels     = $chargeModels     ?? collect();
    @endphp
};

    s#(<x-app-layout>\s*)#$1$block\n# unless index($block, $1) != -1;
  ' "$INDEX"
fi

# ------------------------------------------------------------------
# 2) Ensure bulk_update + history routes exist (FQCN, no extra "use")
# ------------------------------------------------------------------
if [[ -f "$ROUTES" ]]; then
  if grep -q "offers.bulk_update" "$ROUTES"; then
    echo "==> Route name offers.bulk_update already present, skipping route append"
  else
    echo "==> Appending offers bulk_update + history routes"
    cat << 'PHP' >> "$ROUTES"

Route::middleware(['web', 'auth'])->group(function () {
    Route::post('/offers/bulk-update', [\App\Http\Controllers\OffersController::class, 'bulkUpdate'])
        ->name('offers.bulk_update');

    Route::get('/offers/{offer}/history', [\App\Http\Controllers\OffersController::class, 'history'])
        ->name('offers.history');
});
PHP
  fi
fi

echo "==> offers_index_fix_vars_and_routes_v1: done"
