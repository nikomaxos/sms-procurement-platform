#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Fix: register 'admin' middleware alias + clear caches"

# 1) Ensure middleware class exists (no-op if already there)
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

class AdminOnly {
    public function handle(Request $request, Closure $next) {
        if (!Auth::check()) return redirect()->route('login');
        $u = Auth::user();
        if (Schema::hasColumn('users','is_admin')) {
            if (!($u->is_admin ?? false)) abort(403,'Forbidden');
        } else {
            if ((int)($u->id ?? 0) !== 1) abort(403,'Forbidden');
        }
        return $next($request);
    }
}
PHP
fi

# 2) Patch Kernel to register alias 'admin' => AdminOnly::class
K=app/Http/Kernel.php
b "$K"
php -r '
$F="app/Http/Kernel.php"; $c=file_get_contents($F);
if($c===false){fwrite(STDERR,"Cannot read $F\n"); exit(1);}
if (strpos($c,"use App\\Http\\Middleware\\AdminOnly;")===false){
  $c=preg_replace("/^<\\?php\\s+namespace App\\\\Http;/","<?php\nnamespace App\\Http;\nuse App\\Http\\Middleware\\AdminOnly;\n",$c,1);
}
$insert="        '\''admin'\'' => \\\\App\\\\Http\\\\Middleware\\\\AdminOnly::class,";
$patched=false;
$c=preg_replace_callback("/(public|protected)\\s+(?:array\\s+)?\\$middlewareAliases\\s*=\\s*\\[(.*?)\\];/s",
  function($m)use($insert,&$patched){
    $body=$m[2]; if(strpos($body,"'\''admin'\''")!==false) return $m[0];
    $patched=true; return $m[1]." array \$middlewareAliases = [\n".rtrim($body)."\n$insert\n];";
  },$c,1);
if(!$patched){
  $c=preg_replace_callback("/(public|protected)\\s+(?:array\\s+)?\\$routeMiddleware\\s*=\\s*\\[(.*?)\\];/s",
    function($m)use($insert,&$patched){
      $body=$m[2]; if(strpos($body,"'\''admin'\''")!==false) return $m[0];
      $patched=true; return $m[1]." array \$routeMiddleware = [\n".rtrim($body)."\n$insert\n];";
    },$c,1);
}
file_put_contents($F,$c);
echo $patched?"Patched Kernel alias.\n":"Kernel already had alias.\n";
'

# 3) (Optional) Replace any leftover ->middleware('admin') with FQCN in all route files
perl -0777 -pe "s/->middleware\\(\\s*'admin'\\s*\\)/->middleware(\\\\App\\\\Http\\\\Middleware\\\\AdminOnly::class)/g" -i routes/*.php || true

# 4) Clear & rebuild caches inside the PHP container (correctly using $DC)
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l app/Http/Kernel.php
  php -l app/Http/Middleware/AdminOnly.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  php artisan route:list | grep -n "networks\.duplicates" || true
'
echo "==> Done. Try /networks/duplicates"
