#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"

echo "==> Looking for latest OffersController backup under backup_offers_* ..."

LATEST_DIR=""

# Βρίσκει τον πιο πρόσφατο φάκελο backup_offers_* που περιέχει OffersController.php
for d in $(ls -dt backup_offers_* 2>/dev/null || true); do
  if [ -f "$d/app/Http/Controllers/OffersController.php" ]; then
    LATEST_DIR="$d"
    break
  fi
done

if [ -z "$LATEST_DIR" ]; then
  echo "!! No backup_offers_* directory with app/Http/Controllers/OffersController.php found. Aborting."
  exit 1
fi

echo "==> Using backup controller from: $LATEST_DIR"

# Backup του τωρινού (σπασμένου) controller για ασφάλεια
BACKUP_CURRENT="backup_manual_restore_$(date +%F_%H-%M-%S)"
mkdir -p "$BACKUP_CURRENT/app/Http/Controllers"

if [ -f "app/Http/Controllers/OffersController.php" ]; then
  cp app/Http/Controllers/OffersController.php \
     "$BACKUP_CURRENT/app/Http/Controllers/" \
     || echo "WARN: could not backup current OffersController.php"
fi

# Επαναφορά από το τελευταίο working backup
cp "$LATEST_DIR/app/Http/Controllers/OffersController.php" app/Http/Controllers/OffersController.php

echo "==> Restored app/Http/Controllers/OffersController.php from $LATEST_DIR"
echo "==> Previous broken controller stored under: $BACKUP_CURRENT"
