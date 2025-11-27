#!/usr/bin/env bash
set -e

echo "==> Fixing permissions so PHP-FPM can read controllers/views"

# Controllers dir + files
find app/Http/Controllers -type d -exec chmod 755 {} \; || true
find app/Http/Controllers -type f -name '*.php' -exec chmod 644 {} \; || true

# Views dir + files
find resources/views -type d -exec chmod 755 {} \; || true
find resources/views -type f \( -name '*.php' -o -name '*.blade.php' \) -exec chmod 644 {} \; || true

echo "==> Done."
