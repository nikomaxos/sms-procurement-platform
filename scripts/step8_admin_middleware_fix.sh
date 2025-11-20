#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"
b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step8: Admin middleware alias + cache clear"

# 1) Middleware class
F=app/Http/Middleware/AdminOnly.php
b "$F"; mkdir -p "$(dirname "$F")"
cat > "$F" <<'PHP'
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

        if ($isAdmin || $user->id === 1 || strcasecmp($user->email ?? '', 'admin@example.com') === 0) {
            return $next($request);
        }

        abort(403, 'Admins only.');
    }
}
PHP

# 2) Register alias in Kernel ($middlewareAliases or $routeMiddleware)
K=app/Http/Kernel.php
b "$K"
php -r '
$K="app/Http/Kernel.php";
$c=file_get_contents($K);
if ($c===false) {fwrite(STDERR,"Cannot read $K\n"); exit(1);}

if (!preg_match("/use\\s+App\\\\Http\\\\Middleware\\\\AdminOnly;/", $c)) {
    $c=preg_replace("/^namespace\\s+App\\\\Http\\\\;/m", "namespace App\\\\Http\\\\;\n\nuse App\\\\Http\\\\Middleware\\\\AdminOnly;", $c, 1);
}

if (preg_match("/\\$middlewareAliases\\s*=\\s*\\[/", $c)) {
    if (!preg_match("/[\\x27\\\"]admin[\\x27\\\"]\\s*=>/", $c)) {
        $c=preg_replace("/(\\$middlewareAliases\\s*=\\s*\\[[^\\]]*)/s", "$1\n        \x27admin\x27 => AdminOnly::class,", $c, 1);
    }
} elseif (preg_match("/\\$routeMiddleware\\s*=\\s*\\[/", $c)) {
    if (!preg_match("/[\\x27\\\"]admin[\\x27\\\"]\\s*=>/", $c)) {
        $c=preg_replace("/(\\$routeMiddleware\\s*=\\s*\\[[^\\]]*)/s", "$1\n        \x27admin\x27 => AdminOnly::class,", $c, 1);
    }
} else {
    $c=preg_replace("/class\\s+Kernel\\s+extends\\s+HttpKernel\\s*\\{/", "class Kernel extends HttpKernel {\n    protected \$middlewareAliases = [\n        \x27admin\x27 => AdminOnly::class,\n    ];", $c, 1);
}
file_put_contents($K, $c);
'

# 3) Lint + clear caches INSIDE the container
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php -l app/Http/Middleware/AdminOnly.php
  php -l app/Http/Kernel.php
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  echo "==> routes with duplicates page:"
  php artisan route:list | grep -n "networks\.duplicates" || true
'
echo "==> Step8 done. Test /networks/duplicates"
