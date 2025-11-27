#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BACKUP_DIR="backup_networks_fix_destroy_$(date +%F_%H-%M-%S)"
echo "==> Backup dir: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# 1) Backup current (σπασμένο) controller
if [ -f app/Http/Controllers/NetworksController.php ]; then
  echo "==> Backing up app/Http/Controllers/NetworksController.php"
  cp app/Http/Controllers/NetworksController.php \
     "$BACKUP_DIR/NetworksController.php.broken"
fi

# 2) Restore καθαρό controller από git HEAD
echo "==> git restore app/Http/Controllers/NetworksController.php"
git restore app/Http/Controllers/NetworksController.php

# 3) Patch: πρόσθεσε destroy() σωστά μέσα στην class NetworksController
echo "==> Patching NetworksController.php to add destroy() safely"

cat > scripts/_patch_networks_destroy_safe.php << 'PHP'
<?php

$file = __DIR__ . '/../app/Http/Controllers/NetworksController.php';

$code = file_get_contents($file);
if ($code === false) {
    fwrite(STDERR, "Cannot read $file\n");
    exit(1);
}

if (strpos($code, 'function destroy(') !== false) {
    fwrite(STDOUT, "destroy() already exists, skipping.\n");
    exit(0);
}

$classPos = strpos($code, 'class NetworksController');
if ($classPos === false) {
    fwrite(STDERR, "Could not find 'class NetworksController' in file.\n");
    exit(1);
}

$prefix = substr($code, 0, $classPos);
$rest   = substr($code, $classPos);

// Ταιριάζουμε: header της κλάσης, σώμα, και το κλείσιμο "}"
if (!preg_match('/^(class\s+NetworksController[^{]*\{)([\s\S]*)(\}\s*)$/', $rest, $m)) {
    fwrite(STDERR, "Could not split NetworksController class body.\n");
    exit(1);
}

$classHeader = $m[1];  // "class NetworksController ... {"
$classBody   = $m[2];  // όλο το περιεχόμενο μέσα στην κλάση
$classClose  = $m[3];  // κλείσιμο "}\n"

$insert = <<<'PHP_METHOD'

    /**
     * Remove the specified network from storage.
     */
    public function destroy(string $networkId)
    {
        $network = \App\Models\Network::with(['mncs', 'meta'])->findOrFail($networkId);

        // Delete related MNCs and meta first (if relations exist)
        if (method_exists($network, 'mncs')) {
            $network->mncs()->delete();
        }

        if (method_exists($network, 'meta')) {
            $network->meta()->delete();
        }

        $name = $network->name;

        $network->delete();

        return redirect()
            ->route('networks.index')
            ->with('status', "Network '{$name}' deleted successfully.");
    }

PHP_METHOD;

// βάζουμε το destroy() στο τέλος του σώματος της κλάσης, πριν από το τελικό "}"
$newBody = rtrim($classBody) . "\n" . $insert . "\n";

$newCode = $prefix . $classHeader . $newBody . $classClose;

file_put_contents($file, $newCode);
fwrite(STDOUT, "destroy() added successfully.\n");
PHP

php scripts/_patch_networks_destroy_safe.php
rm -f scripts/_patch_networks_destroy_safe.php

# 4) Syntax check + clear caches
echo "==> Syntax check + optimize:clear inside app container"
docker compose exec app sh -lc '
  cd /var/www/html &&
  php -l app/Http/Controllers/NetworksController.php &&
  php artisan view:clear &&
  php artisan optimize:clear || true
'

echo "==> Done. Test /networks and deleting a test network."
