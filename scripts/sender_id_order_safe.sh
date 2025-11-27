#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backup_sender_id_order_safe_$(date +%F_%H-%M-%S)"

echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/app/Http/Controllers"

cp app/Http/Controllers/OffersController.php "${BACKUP_DIR}/app/Http/Controllers/" || true

echo "==> Ensure Schema facade is imported"
perl -0pi -e 's/use Illuminate\\Http\\Request;\n/use Illuminate\\Http\\Request;\nuse Illuminate\\Support\\Facades\\Schema;\n/' app/Http/Controllers/OffersController.php

echo "==> Wrap ALL Sender ID queries (dropdown_menu_id = 3) with safe sort_order check"
perl -0pi -e '
s/DropdownItem::where\(\'dropdown_menu_id\', 3\).*?->orderBy\(\'label\'\)\s*->get\(\);/DropdownItem::where('\''dropdown_menu_id'\'', 3)
            ->when(Schema::hasColumn('\''dropdown_items'\'', '\''sort_order'\''), function ($q) {
                $q->orderBy('\''sort_order'\'');
            })
            ->orderBy('\''label'\'')
            ->get();/gs
' app/Http/Controllers/OffersController.php

echo "==> Done. Backup in: ${BACKUP_DIR}"
