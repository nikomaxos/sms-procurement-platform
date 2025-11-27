#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_sender_id_order_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/app/Http/Controllers"
cp app/Http/Controllers/OffersController.php "${BACKUP_DIR}/app/Http/Controllers/" || true

##
## 1) Στα create/edit: Sender ID Supported options -> orderBy('sort_order')->orderBy('label')
##
perl -pi -e "s/DropdownItem::where\('dropdown_menu_id', 3\)->orderBy\('label'\)->get\(\)/DropdownItem::where('dropdown_menu_id', 3)->orderBy('sort_order')->orderBy('label')->get()/g" app/Http/Controllers/OffersController.php

##
## 2) Στο filters του index: Sender ID Supported filter -> ίδια σειρά
##
perl -0pi -e "s/\$senderIdFilterOptions = DropdownItem::where\('dropdown_menu_id', 3\)\s*->orderBy\('label'\)\s*->get\(\);/\$senderIdFilterOptions = DropdownItem::where('dropdown_menu_id', 3)\n            ->orderBy('sort_order')\n            ->orderBy('label')\n            ->get();/g" app/Http/Controllers/OffersController.php

echo '==> Done. Backup in: '"${BACKUP_DIR}"
