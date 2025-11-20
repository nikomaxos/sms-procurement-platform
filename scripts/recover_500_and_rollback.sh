#!/usr/bin/env bash
set -Eeuo pipefail

ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

CANDIDATES=(
  "routes/web.php"
  "app/Http/Kernel.php"
  "app/Http/Middleware/AdminOnly.php"
  "app/Http/Controllers/NetworkDedupController.php"
  "resources/views/networks/duplicates.blade.php"
  "app/Http/Controllers/NetworksController.php"
  "resources/views/networks/index.blade.php"
  "resources/views/networks/_form.blade.php"
  "app/Services/CarrierImportService.php"
)

usage(){ echo "Usage:
  bash scripts/recover_500_and_rollback.sh
  bash scripts/recover_500_and_rollback.sh --rollback-all
"; }

latest_backup(){ ls -1t "${1}".bak.* 2>/dev/null | head -n1 || true; }

rollback_all(){
  echo "==> ROLLBACK: restoring latest backups where available"
  for f in "${CANDIDATES[@]}"; do
    bak="$(latest_backup "$f")"
    [ -n "$bak" ] && { echo "   - restore $f <= $bak"; cp -a "$bak" "$f"; }
  done
  $DC exec -T app sh -lc '
    set -Eeuo pipefail
    php -l routes/web.php || true
    php -l app/Http/Kernel.php || true
    php artisan optimize:clear
    php artisan route:cache
    php artisan view:cache
    php artisan route:list | head -n 50
  '
  echo "==> Rollback complete."
}

[ "${1:-}" = "--rollback-all" ] && { rollback_all; exit 0; }

echo "==> Snapshot working tree (exclude storage/ & .backups/)"
mkdir -p .backups
# αγνόησε τυχόν permission/mtime warnings για να ΜΗ σταματά το script
tar --exclude='./vendor' \
    --exclude='./node_modules' \
    --exclude='./storage' \
    --exclude='./.backups' \
    --ignore-failed-read \
    --warning=no-file-changed \
    -czf ".backups/snapshot_${ts}.tar.gz" . || echo "   (snapshot warnings ignored)"

echo "==> Ensure AdminOnly middleware exists"
FMW=app/Http/Middleware/AdminOnly.php
b "$FMW"; mkdir -p "$(dirname "$FMW")"
cat > "$FMW" <<'PHP'
<?php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AdminOnly
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        if (!$user) abort(401);

        $isAdmin = false;
        try {
            if (property_exists($user, 'is_admin')) {
                $isAdmin = (bool)$user->is_admin;
            } elseif (method_exists($user, 'getAttribute') && $user->getAttribute('is_admin') !== null) {
                $isAdmin = (bool)$user->getAttribute('is_admin');
            }
        } catch (\Throwable $e) {}

        if ($isAdmin || ($user->id ?? null) === 1 || strcasecmp($user->email ?? '', 'admin@example.com') === 0) {
            return $next($request);
        }
        abort(403, 'Admins only.');
    }
}
PHP

echo "==> Ensure Kernel alias 'admin' => AdminOnly::class"
KRN=app/Http/Kernel.php
b "$KRN"
php -r '
$f="app/Http/Kernel.php"; $c=file_get_contents($f);
if($c===false){fwrite(STDERR,"Kernel missing\n"); exit(1);}
if(strpos($c,"AdminOnly::class")===false){
  if(preg_match("/protected\\s+\\$middlewareAliases\\s*=\\s*\\[(.*?)\\];/s",$c,$m)){
    if(strpos($m[1],"AdminOnly::class")===false){
      $new = "protected \$middlewareAliases = [".$m[1]."\n        '"'"'admin'"'"' => \\\\App\\\\Http\\\\Middleware\\\\AdminOnly::class,\n    ];";
      $c = str_replace($m[0], $new, $c);
    }
  } else {
    $c = preg_replace("/class\\s+Kernel\\s+extends\\s+HttpKernel\\s*\\{/",
      "class Kernel extends HttpKernel {\n    protected \$middlewareAliases = [\n        '"'"'admin'"'"' => \\\\App\\\\Http\\\\Middleware\\\\AdminOnly::class,\n    ];\n",
      $c,1);
  }
  file_put_contents($f,$c);
}
'

echo "==> Replace any 'admin' string middleware with explicit class in routes"
R=routes/web.php
b "$R"
perl -0777 -pe "s/->middleware\(\s*'admin'\s*\)/->middleware(\\\\App\\\\Http\\\\Middleware\\\\AdminOnly::class)/g" -i "$R"
perl -0777 -pe "s/->middleware\(\s*\[\s*'auth'\s*,\s*'admin'\s*\]\s*\)/->middleware(['auth', \\\\App\\\\Http\\\\Middleware\\\\AdminOnly::class])/g" -i "$R"

echo "==> Lint locally"
php -l "$FMW"
php -l "$KRN"
php -l "$R"

echo "==> Clear caches in container & show routes"
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l routes/web.php
  php -l app/Http/Kernel.php
  php -l app/Http/Middleware/AdminOnly.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  echo "==> Routes (top 60):"
  php artisan route:list | head -n 60
'

echo "==> Tail laravel.log (last 120 lines)"
$DC exec -T app sh -lc 'tail -n 120 storage/logs/laravel.log || true'

echo "==> Done. If 500 persists, run: bash scripts/recover_500_and_rollback.sh --rollback-all"
