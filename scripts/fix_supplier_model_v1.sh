#!/usr/bin/env bash
set -euo pipefail

##
# fix_supplier_model_v1.sh
#
# Rewrites app/Models/Supplier.php as a clean, valid model:
# - fields: name, email, notes
# - relation: connections() (1:N -> SupplierConnection)
##

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
  pwd
)"
cd "$ROOT_DIR"

MODEL_FILE="app/Models/Supplier.php"
STAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR=".backups/fix_supplier_model_${STAMP}"

echo "==> Backing up ${MODEL_FILE} to ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"
if [[ -f "${MODEL_FILE}" ]]; then
  cp "${MODEL_FILE}" "${BACKUP_DIR}/Supplier.php"
fi

echo "==> Rewriting ${MODEL_FILE} with clean definition"
cat > "${MODEL_FILE}" <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Supplier extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'email',
        'notes',
    ];

    public function connections()
    {
        return $this->hasMany(SupplierConnection::class);
    }
}
PHP

echo "==> Optional: syntax check inside container (if running)"
if command -v docker >/dev/null 2>&1; then
  docker compose exec -T app bash -lc 'cd /var/www/html && php -l app/Models/Supplier.php' || \
    echo "   (php -l failed or container not running; check manually if needed)"
fi

echo "==> Done. Supplier model reset to a valid state."
