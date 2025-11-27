#!/usr/bin/env bash
set -e

cd ~/sms-procurement-platform

BACKUP_DIR="backup_sender_id_no_alpha_sort_$(date +%F_%H-%M-%S)"
echo "==> Backup dir: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR/app/Http/Controllers"

cp app/Http/Controllers/OffersController.php "$BACKUP_DIR/app/Http/Controllers/" || true

echo "==> Removing alphabetical sort only for dropdown_menu_id = 3 (Sender ID Supported)..."

# Βρίσκει όλα τα κομμάτια τύπου:
#   DropdownItem::where('dropdown_menu_id', 3) ... ->orderBy('label')
# και αφαιρεί ΜΟΝΟ το ->orderBy('label'), αφήνοντας τα υπόλοιπα ως έχουν.
perl -0pi -e "s/(DropdownItem::where\('dropdown_menu_id', 3\)[\s\S]*?)\s*->orderBy\('label'\)/\1/g" app/Http/Controllers/OffersController.php

echo "==> Done. Backup stored in $BACKUP_DIR"
