#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"; b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step8b: register 'admin' middleware alias in Kernel (Laravel 12-compatible)"

# Ensure middleware class exists (no-op if already there)
mkdir -p app/Http/Middleware
MW=app/Http/Middleware/AdminOnly.php
if [ ! -f "$MW" ]; then
  cat > "$MW" <<'PHP'
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Schema;

class AdminOnly
{
    public function handle(Request $request, Closure $next)
    {
        if (!Auth::check()) {
            return redirect()->route('login');
        }
        $u = Auth::user();

        if (Schema::hasColumn('users','is_admin')) {
            if (!($u->is_admin ?? false)) {
                abort(403, 'Forbidden');
            }
        } else {
            if ((int)($u->id ?? 0) !== 1) {
                abort(403, 'Forbidden');
            }
        }
        return $next($request);
    }
}
PHP
fi

K=app/Http/Kernel.php
b "$K"

php -r '
$F="app/Http/Kernel.php";
$c=file_get_contents($F);
if($c===false){fwrite(STDERR,"Cannot read $F\n"); exit(1);}

# Ensure use statement
if (strpos($c, "use App\\Http\\Middleware\\AdminOnly;") === false) {
  $c=preg_replace(
    "/^<\\?php\\s+namespace App\\\\Http;(\\s+)/",
    "<?php\nnamespace App\\Http;\\1use App\\Http\\Middleware\\AdminOnly;\n",
    $c, 1
  );
}

$insert = "        '\''admin'\'' => \\\\App\\\\Http\\\\Middleware\\\\AdminOnly::class,";

$patched = false;

# Prefer $middlewareAliases (Laravel 11/12)
$c = preg_replace_callback(
  "/(public|protected)\\s+(?:array\\s+)?\\$middlewareAliases\\s*=\\s*\\[(.*?)\\];/s",
  function($m) use ($insert, &$patched){
      $body = $m[2];
      if (strpos($body, "'\''admin'\''") !== false) return $m[0];
      $body = rtrim($body)."\n".$insert."\n";
      $patched = true;
      return $m[1]." array \$middlewareAliases = [\n".$body."];";
  },
  $c, 1
);

# Fallback: $routeMiddleware (older apps)
if(!$patched){
  $c = preg_replace_callback(
    "/(public|protected)\\s+(?:array\\s+)?\\$routeMiddleware\\s*=\\s*\\[(.*?)\\];/s",
    function($m) use ($insert, &$patched){
        $body = $m[2];
        if (strpos($body, "'\''admin'\''") !== false) return $m[0];
        $body = rtrim($body)."\n".$insert."\n";
        $patched = true;
        return $m[1]." array \$routeMiddleware = [\n".$body."];";
    },
    $c, 1
  );
}

file_put_contents($F,$c);
echo $patched ? "Patched Kernel alias.\n" : "Kernel already had alias (no changes).\n";
'

# Warm caches in container
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l app/Http/Kernel.php
  php -l app/Http/Middleware/AdminOnly.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  php artisan route:list | grep -n "networks\.duplicates" || true
'
echo "==> Step8b done. Visit /networks/duplicates again."
