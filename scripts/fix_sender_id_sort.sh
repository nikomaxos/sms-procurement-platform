#!/usr/bin/env bash
set -e

cd ~/sms-procurement-platform

BACKUP_DIR="backup_fix_sender_id_sort_$(date +%F_%H-%M-%S)"
echo "==> Backup dir: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR/app/Http/Controllers"

cp app/Http/Controllers/OffersController.php "$BACKUP_DIR/app/Http/Controllers/" || true

# Αφαίρεση οποιουδήποτε ->orderBy('sort_order') ή "sort_order"
perl -pi -e "s/->orderBy\('sort_order'\)//g" app/Http/Controllers/OffersController.php
perl -pi -e "s/->orderBy\(\"sort_order\"\)//g" app/Http/Controllers/OffersController.php

echo "==> Done. Backup stored in $BACKUP_DIR"
