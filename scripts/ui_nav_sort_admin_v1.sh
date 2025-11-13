# scripts/ui_nav_sort_admin_v1.sh
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

mkdir -p resources/views/{countries,networks,partials} app/Http/Controllers app/Http/Middleware

############################
# Countries index (no Fresh)
############################
cat > resources/views/countries/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Countries</h2></x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <form method="GET" class="flex items-center gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Search name/ISO2…" class="rounded border px-3 py-2">
        <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC…" class="rounded border px-3 py-2">
        <select name="per" class="rounded border px-2 py-2">
          @foreach([20,50,100,1000] as $opt)<option value="{{ $opt }}" @selected((int)request('per',20)===$opt)>{{ $opt }}</option>@endforeach
        </select>
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      </form>

      {{-- Update only (no Fresh here) --}}
      @if (\Illuminate\Support\Facades\Route::has('carriers.import'))
      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-2">
        @csrf
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Update from source</button>
      </form>
      @endif

      <a href="{{ route('countries.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Country</a>
    </div>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">ISO2</th>
            <th class="px-3 py-2 text-left">MCCs</th>
            <th class="px-3 py-2 text-left">Created</th>
            <th class="px-3 py-2 text-left">Updated</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($countries as $c)
          <tr class="border-t">
            <td class="px-3 py-2">{{ $c->name }}</td>
            <td class="px-3 py-2">{{ $c->iso2 }}</td>
            <td class="px-3 py-2">
              @foreach(($c->mccs ?? []) as $m)
                <span class="inline-block rounded bg-gray-100 px-2 py-0.5 mr-1">{{ $m->mcc }}</span>
              @endforeach
            </td>
            <td class="px-3 py-2">{{ optional($c->created_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2">{{ optional($c->updated_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2 text-right">
              <a href="{{ route('countries.edit',$c) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
              <form method="POST" action="{{ route('countries.destroy',$c) }}" class="inline-block" onsubmit="return confirm('Delete country?')">
                @csrf @method('DELETE')
                <button class="rounded px-3 py-2 bg-red-600 text-white hover:bg-red-700">Delete</button>
              </form>
            </td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $countries->appends(request()->all())->links() }}</div>
  </div>
</x-app-layout>
BLADE

############################################
# Networks index (Country first + Fresh here)
############################################
cat > resources/views/networks/index.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2></x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm whitespace-pre-wrap">{{ session('status') }}</div>
    @endif

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <form method="GET" class="flex items-center gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Search name…" class="rounded border px-3 py-2">
        <input name="mcc" value="{{ request('mcc') }}" placeholder="MCC…" class="rounded border px-3 py-2">
        <input name="mnc" value="{{ request('mnc') }}" placeholder="MNC…" class="rounded border px-3 py-2">
        <input name="mcc_mnc" value="{{ request('mcc_mnc') }}" placeholder="MCC-MNC…" class="rounded border px-3 py-2">
        <input name="country" value="{{ request('country') }}" placeholder="Country…" class="rounded border px-3 py-2">
        <select name="per" class="rounded border px-2 py-2">
          @foreach([20,50,100,1000] as $opt)<option value="{{ $opt }}" @selected((int)request('per',20)===$opt)>{{ $opt }}</option>@endforeach
        </select>
        <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      </form>

      @if (\Illuminate\Support\Facades\Route::has('carriers.import'))
      <form method="POST" action="{{ route('carriers.import') }}" class="flex items-center gap-2">
        @csrf
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Update from source</button>
        <input type="hidden" name="fresh" value="1">
        <button class="rounded bg-red-600 px-4 py-2 text-white hover:bg-red-700" onclick="return confirm('Full refresh?')">Fresh import</button>
      </form>
      @endif

      <a href="{{ route('networks.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Network</a>
    </div>

    <div class="overflow-x-auto bg-white rounded border">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left">Country</th>
            <th class="px-3 py-2 text-left">MCC-MNC</th>
            <th class="px-3 py-2 text-left">MCC</th>
            <th class="px-3 py-2 text-left">MNC</th>
            <th class="px-3 py-2 text-left">Network</th>
            <th class="px-3 py-2 text-left">Created</th>
            <th class="px-3 py-2 text-left">Updated</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($networks as $n)
          <tr class="border-t">
            <td class="px-3 py-2">{{ optional($n->country)->name ?? $n->country_name }}</td>
            <td class="px-3 py-2 font-mono">{{ $n->mcc_mnc }}</td>
            <td class="px-3 py-2">{{ $n->mcc }}</td>
            <td class="px-3 py-2">{{ $n->mnc }}</td>
            <td class="px-3 py-2">{{ $n->name }}</td>
            <td class="px-3 py-2">{{ optional($n->created_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2">{{ optional($n->updated_at)->format('Y-m-d H:i') }}</td>
            <td class="px-3 py-2 text-right">
              <a href="{{ route('networks.edit',$n) }}" class="rounded px-3 py-2 bg-gray-200 hover:bg-gray-300">Edit</a>
              <form method="POST" action="{{ route('networks.destroy',$n) }}" class="inline-block" onsubmit="return confirm('Delete network?')">
                @csrf @method('DELETE')
                <button class="rounded px-3 py-2 bg-red-600 text-white hover:bg-red-700">Delete</button>
              </form>
            </td>
          </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div class="mt-4">{{ $networks->appends(request()->all())->links() }}</div>
  </div>
</x-app-layout>
BLADE

############################################
# NetworksController: order by country, then mcc_mnc
############################################
php <<'PHP'
<?php
$f = 'app/Http/Controllers/NetworksController.php';
if (!file_exists($f)) { fwrite(STDERR,"Missing $f\n"); exit(0); }
$s = file_get_contents($f);

// Ensure signature: index(Request $r)
if (!preg_match('/function\s+index\s*\(\s*[^)]*Request\s+\$r/i', $s)) {
  $s = preg_replace('/function\s+index\s*\([^)]*\)/', 'function index(\Illuminate\Http\Request $r)', $s, 1);
}

// Inject join + select + ordering
if (strpos($s, "countries.name as country_name") === false || !preg_match('/orderBy\(/i',$s)) {
  $s = preg_replace(
    '/(\$q\s*=\s*Network::query\(\)[^\;]*;)/s',
    "\$q = Network::query()\n            ->with('country')\n            ->leftJoin('countries','countries.id','=','networks.country_id')\n            ->select('networks.*','countries.name as country_name');",
    $s, 1
  );

  // country name filter on joined table
  if (strpos($s, "->when(\$r->filled('country')") === false) {
    $s = preg_replace(
      '/(\$q\s*=\s*Network::query[^\;]*;)/s',
      "$0\n        // country filter on join\n        \$q->when(\$r->filled('country'), function(\$q) use (\$r){ \$q->where('countries.name','ilike','%'.\$r->country.'%'); });",
      $s, 1
    );
  }

  // mcc_mnc filter if missing
  if (strpos($s, "mcc_mnc','ilike'") === false) {
    $s = preg_replace(
      '/(->when\(\s*\$r->filled\(\s*[\'"]mnc[\'"]\s*\)[^\)]*\)\s*\);)/s',
      "->when(\$r->filled('mnc'), function(\$q) use (\$r){ \$q->where('mnc', \$r->mnc); })\n            ->when(\$r->filled('mcc_mnc'), function(\$q) use (\$r){ \$q->where('mcc_mnc','ilike','%'.\$r->mcc_mnc.'%'); });",
      $s, 1
    );
  }

  // order after filters (country asc, then mcc_mnc asc)
  if (!preg_match('/orderBy\(\s*[\'"]countries\.name[\'"]/i', $s)) {
    $s = preg_replace(
      '/(\$networks\s*=\s*\$q[^\;]*)(;)/',
      "\$networks = \$q->orderBy('countries.name','asc')->orderBy('networks.mcc_mnc','asc')$2",
      $s, 1
    );
  }
}

// per=20/50/100/1000 guard + appends
if (!preg_match('/\$per\s*=\s*/',$s)) {
  $s = preg_replace(
    '/(\$networks\s*=\s*\$q[^\;]*paginate\()[^)]*(\)\s*;)/',
    "\$per = (int) max(1, min(1000, (int) \$r->integer('per',20)));\n        if (!in_array(\$per,[20,50,100,1000], true)) { \$per = 20; }\n        \$networks = \$q->orderBy('countries.name','asc')->orderBy('networks.mcc_mnc','asc')->paginate(\$per)->appends(\$r->all());",
    $s, 1
  );
} else {
  $s = preg_replace('/->paginate\([^)]*\)\s*;/', '->paginate($per)->appends($r->all());', $s, 1);
}

file_put_contents($f,$s);
PHP

###################################################
# CountriesController: ensure MCC filter & per appends
###################################################
php <<'PHP'
<?php
$f = 'app/Http/Controllers/CountriesController.php';
if (!file_exists($f)) { exit(0); }
$s = file_get_contents($f);

// per guard
if (strpos($s, '$per =') === false) {
  $s = preg_replace('/(\$countries\s*=\s*\$q[^\;]*paginate\()[^)]*(\)\s*;)/',
    "\$per = (int) max(1, min(1000, (int) request()->integer('per',20)));\n        if (!in_array(\$per,[20,50,100,1000], true)) { \$per = 20; }\n        \$countries = \$q->paginate(\$per)->appends(request()->all());",
    $s, 1);
} else {
  $s = preg_replace('/->paginate\([^)]*\)\s*;/', '->paginate($per)->appends(request()->all());', $s, 1);
}

// add MCC filter if missing (exists table country_mccs)
if (strpos($s, "country_mccs") === false) {
  $s = preg_replace('/(\$q\s*=\s*Country::query\(\)[^\;]*;)/s',
    "$0\n        \$q->when(request()->filled('mcc'), function(\$q){\n            \$mcc = request('mcc');\n            \$q->whereIn('id', \\App\\Models\\CountryMcc::where('mcc', \$mcc)->pluck('country_id'));\n        });",
    $s, 1);
}

file_put_contents($f,$s);
PHP

############################################
# Sidebar: add Users Management & admin-only IMAP
############################################
SID="resources/views/partials/sidebar.blade.php"

# Users Management link (only if route exists); avoid duplicates
if ! grep -q "users.index" "$SID" 2>/dev/null; then
  php <<'PHP'
<?php
$f = 'resources/views/partials/sidebar.blade.php';
if (!file_exists($f)) { exit(0); }
$s = file_get_contents($f);
$block = <<<'BLADE'
@if(\Illuminate\Support\Facades\Route::has('users.index'))
  <a href="{{ route('users.index') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
    <span class="material-icons text-sm">group</span><span>Users Management</span>
  </a>
@endif

BLADE;
$s = preg_replace('/(@include\(\'partials\.catalog_links\'\)\s*)/i', "$1$block", $s, 1, $cnt);
if ($cnt===0) { $s = $block . $s; }
file_put_contents($f,$s);
PHP
fi

# IMAP Settings admin-only (guarded)
if ! grep -q "IMAP Settings" "$SID" 2>/dev/null; then
  php <<'PHP'
<?php
use Illuminate\Support\Str;
$f = 'resources/views/partials/sidebar.blade.php';
if (!file_exists($f)) { exit(0); }
$s = file_get_contents($f);
$block = <<<'BLADE'
@php($u = auth()->user())
@php($imapRoute = \Illuminate\Support\Facades\Route::has('settings.imap.index') ? 'settings.imap.index' : (\Illuminate\Support\Facades\Route::has('settings.imap') ? 'settings.imap' : null))
@if($imapRoute && $u && ( ($u->is_admin ?? false) || (($u->role ?? ($u->type ?? '')) === 'admin') ))
  <a href="{{ route($imapRoute) }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
    <span class="material-icons text-sm">mail</span><span>IMAP Settings</span>
  </a>
@endif

BLADE;
$s = preg_replace('/(@include\(\'partials\.catalog_links\'\)\s*)/i', "$1$block", $s, 1, $cnt);
if ($cnt===0) { $s = $block . $s; }
file_put_contents($f,$s);
PHP
fi

############################################
# Optional: create admin middleware & register alias
############################################
cat > app/Http/Middleware/AdminOnly.php <<'PHP'
<?php
namespace App\Http\Middleware;
use Closure;
use Illuminate\Http\Request;

class AdminOnly {
  public function handle(Request $request, Closure $next){
    $u = $request->user();
    $isAdmin = $u && ( ($u->is_admin ?? false) || (($u->role ?? ($u->type ?? '')) === 'admin') );
    abort_unless($isAdmin, 403);
    return $next($request);
  }
}
PHP

# Register alias 'admin' if missing
php <<'PHP'
<?php
$f='app/Http/Kernel.php';
if (!file_exists($f)) exit(0);
$s=file_get_contents($f);
if (strpos($s,'AdminOnly::class')===false) {
  $s=preg_replace('/class\s+Kernel\s+extends\s+HttpKernel\s*\{/',
    "class Kernel extends HttpKernel {\n    protected \$routeMiddleware = [\n        'admin' => \\App\\Http\\Middleware\\AdminOnly::class,\n    ];\n",
    $s,1);
  if ($s===null) $s = file_get_contents($f); // fail-safe
  if (strpos($s,'routeMiddleware')===false) {
    // try append into existing Kernel class
    $s=preg_replace('/\}\s*$/', "    protected \$routeMiddleware = [ 'admin' => \\App\\Http\\Middleware\\AdminOnly::class ];\n}\n", $s,1);
  }
  file_put_contents($f,$s);
}
PHP

# Optionally add ->middleware('admin') to IMAP routes (if plainly declared)
sed -i -E "s@(Route::(get|post|match)\('(/)?settings/imap[^']*',\s*\[[^]]+\])@\1->middleware('admin')@g" routes/web.php || true

############################################
# Warm caches
############################################
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "Done: Fresh import is on Networks, sorting by Country->MCC-MNC, Users menu restored, IMAP link admin-only."
