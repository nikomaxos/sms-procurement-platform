#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TS="$(date +%F_%H-%M-%S)"
BACKUP_DIR="$ROOT/backup_fix_version_history_type_note_columns_${TS}"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/fix_version_history_type_note_columns_${TS}.log"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# Log everything
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Working dir: $ROOT"
echo "==> Backup dir:  $BACKUP_DIR"
echo "==> Log file:    $LOG_FILE"

VIEW_FILE="$ROOT/resources/views/settings/version-history.blade.php"

if [ ! -f "$VIEW_FILE" ]; then
  echo "   [ERROR] View not found: $VIEW_FILE"
  exit 1
fi

cp "$VIEW_FILE" "$BACKUP_DIR/$(basename "$VIEW_FILE")"
echo "   [backup] $VIEW_FILE -> $BACKUP_DIR/$(basename "$VIEW_FILE")"

echo "==> Patching Type/Note column rendering..."
# We ONLY touch the two table cells:
# - Type column: use $snapshot['note'] as the type source
# - Note column: use $snapshot['type'] as the note source
perl -0pi -e '
  # Pill color condition: base it on snapshot[\"note\"] instead of snapshot[\"type\"]
  s/@if\(\(\$snapshot\['\''type'\''\] \?\? '\''manual'\''\) === '\''auto'\''\)/
    @if((\$snapshot['\''note'\''] ?? '\''manual'\'') === '\''auto'\'')/g;

  # Pill label text: use snapshot[\"note\"] instead of snapshot[\"type\"]
  s/\{\{\s*\$snapshot\['\''type'\''\]\s*\?\?\s*'\''manual'\''\s*\}\}/{{ \$snapshot['\''note'\''] ?? '\''manual'\'' }}/g;

  # Text in the Note column: show snapshot[\"type\"] instead of snapshot[\"note\"]
  s/\{\{\s*\$snapshot\['\''note'\''\]\s*\?\?\s*'\'''\'']\s*\}\}/{{ \$snapshot['\''type'\''] ?? '\'''\'' }}/g;
' "$VIEW_FILE"

echo "==> Done. Backups stored in: $BACKUP_DIR"
echo "You can rollback via:"
echo "  cp \"$BACKUP_DIR/$(basename "$VIEW_FILE")\" \"$VIEW_FILE\""
