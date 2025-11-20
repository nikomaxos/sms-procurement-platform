#!/usr/bin/env bash
set -Eeuo pipefail
ts="$(date +%F_%H-%M-%S)"; b(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
echo "==> Step8 hotfix: admin middleware + view fix + migrate + cache"

mkdir -p app/Http/Middleware database/migrations tools/patches

# 1) Middleware: AdminOnly
FMW=app/Http/Middleware/AdminOnly.php
b "$FMW"
cat > "$FMW" <<'PHP'
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

        $user = Auth::user();

        // Αν υπάρχει στήλη is_admin, τη χρησιμοποιούμε
        if (Schema::hasColumn('users', 'is_admin')) {
            if ($user->is_admin) {
                return $next($request);
            }
        } else {
            // [Inference] Fallback: θεωρούμε admin τον user_id=1
            if ((int)$user->id === 1) {
                return $next($request);
            }
        }

        abort(403, 'Forbidden');
    }
}
PHP

# 2) Kernel alias 'admin'
K=app/Http/Kernel.php
b "$K"
php -r '
$F="app/Http/Kernel.php"; $c=file_get_contents($F);
if(strpos($c,"use App\\\\Http\\\\Middleware\\\\AdminOnly;")===false){
  $c=preg_replace("/^<\\?php\\s+namespace App\\\\Http\\\\;/","<?php\nnamespace App\\Http;\n\nuse App\\Http\\Middleware\\AdminOnly;", $c,1);
}
if(strpos($c,"'admin' => AdminOnly::class")===false){
  $c=preg_replace("/protected \\$routeMiddleware\\s*=\\s*\\[(.*?)\\];/s",
    "protected \$routeMiddleware = [\$1\n        'admin' => AdminOnly::class,\n    ];",$c,1);
}
file_put_contents($F,$c);
'

# 3) Migration για users.is_admin (αν λείπει)
M="database/migrations/2025_11_14_000900_add_is_admin_to_users.php"
if [ ! -f "$M" ]; then
cat > "$M" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasColumn('users','is_admin')) {
            Schema::table('users', function (Blueprint $table) {
                $table->boolean('is_admin')->default(false)->index();
            });
        }
    }
    public function down(): void {
        if (Schema::hasColumn('users','is_admin')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('is_admin');
            });
        }
    }
};
PHP
fi

# 4) View fix: stray ">” μετά από @endif στο networks/duplicates
V=resources/views/networks/duplicates.blade.php
if [ -f "$V" ]; then
  b "$V"
  perl -0777 -pe 's/\@endif>\s/\@endif\n/g' -i "$V"
fi

# 5) Migrate + ορισμός admin + cache
$DC exec -T app sh -lc '
  set -Eeuo pipefail
  php artisan migrate --force
  php -r "
  require \"vendor/autoload.php\";
  \$app = require \"bootstrap/app.php\";
  \$app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap();
  if (Illuminate\\Support\\Facades\\Schema::hasColumn(\"users\",\"is_admin\")) {
      Illuminate\\Support\\Facades\\DB::table(\"users\")->where(\"id\",1)->update([\"is_admin\"=>true]);
      echo \"Set user#1 is_admin=1\\n\";
  } else {
      echo \"No is_admin column (using fallback user#1 in middleware)\\n\";
  }
  ";
  php artisan optimize:clear
  php artisan route:cache
  php artisan view:cache
  php artisan route:list | grep -E "networks\.duplicates|countries\.mccs\.reassign" || true
'
echo "==> Done. Δοκίμασε τώρα: /networks/duplicates (ως admin) και /countries/{id}/edit (panel Μεταφορά MCC)."
