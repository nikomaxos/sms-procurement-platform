#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

SIDEBAR="resources/views/partials/sidebar.blade.php"
CN_IDX="resources/views/countries/index.blade.php"
NW_IDX="resources/views/networks/index.blade.php"
NW_FORM_PART="resources/views/networks/_form.blade.php"
NW_CREATE="resources/views/networks/create.blade.php"
CT_CREATE="resources/views/countries/create.blade.php"
NW_CTL="app/Http/Controllers/NetworksController.php"
CT_CTL="app/Http/Controllers/CountriesController.php"
SEED="storage/app/carriers/mcc-mnc-seed.json"

mkdir -p "$(dirname "$SIDEBAR")" storage/app/carriers

echo "==> 1) Sidebar: remove old include & ensure Countries/Networks appear once above Settings"
# remove any accidental include we added earlier
if [ -f "$SIDEBAR" ]; then
  cp -a "$SIDEBAR" "$SIDEBAR.bak.$(date +%F_%H-%M-%S)"
  # Strip our previous partial include (if present)
  sed -i '/partials.countries_networks_links/d' "$SIDEBAR"
  # Remove any previous hard-coded duplicate entries to avoid duplicates
  sed -i "/route('countries.index')/d" "$SIDEBAR" || true
  sed -i "/route('networks.index')/d" "$SIDEBAR" || true

  # Insert links immediately before the first Settings link
  perl -0777 -i -pe '
    my $block = qq{
      <a href="{{ route('\''countries.index'\'') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
        <span class="material-icons text-sm">public</span>
        <span>Countries</span>
      </a>
      <a href="{{ route('\''networks.index'\'') }}" class="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100">
        <span class="material-icons text-sm">cell_tower</span>
        <span>Networks</span>
      </a>
    };
    s{(\s*<a\s+href=\"{{\s*route\(\s*'\''settings\.)}{$block$1}i unless index($_, "route('\''countries.index'\'')")!=-1;
    $_;
  ' "$SIDEBAR"
else
  echo "   -> $SIDEBAR not found; skipping nav placement."
fi

echo "==> 2) Buttons: make 'Add Country' / 'Add Network' visible with same styling as other buttons"
# Countries index
if [ -f "$CN_IDX" ]; then
  cp -a "$CN_IDX" "$CN_IDX.bak.$(date +%F_%H-%M-%S)"
  # Replace any transparent/unstyled Add button with a blue one
  perl -0777 -i -pe "
    s{(<a[^>]*href=\"{{\s*route\('countries.create'\)\s*}}\")[^>]*>(\s*Add Country\s*)</a>}
     {<a href=\"{{ route('countries.create') }}\" class=\"rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700\">Add Country</a>}igs;
  " "$CN_IDX"
fi

# Networks index
if [ -f "$NW_IDX" ]; then
  cp -a "$NW_IDX" "$NW_IDX.bak.$(date +%F_%H-%M-%S)"
  perl -0777 -i -pe "
    s{(<a[^>]*href=\"{{\s*route\('networks.create'\)\s*}}\")[^>]*>(\s*Add Network\s*)</a>}
     {<a href=\"{{ route('networks.create') }}\" class=\"rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700\">Add Network</a>}igs;
  " "$NW_IDX"
fi

echo "==> 3) Fix 'Undefined variable \$network' on /networks/create"
# Harden form partial (define default $network)
mkdir -p "$(dirname "$NW_FORM_PART")"
if [ -f "$NW_FORM_PART" ]; then
  cp -a "$NW_FORM_PART" "$NW_FORM_PART.bak.$(date +%F_%H-%M-%S)"
else
  touch "$NW_FORM_PART"
fi
# Prepend a guard only once
grep -q "@php(\$network =" "$NW_FORM_PART" || \
  sed -i '1i @php($network = $network ?? new \\App\\Models\\Network)' "$NW_FORM_PART"

# Make sure controller passes a fresh model to the create view
if [ -f "$NW_CTL" ]; then
  cp -a "$NW_CTL" "$NW_CTL.bak.$(date +%F_%H-%M-%S)"
  # Replace/create a create() method that passes $network
  php -r '
    $f="app/Http/Controllers/NetworksController.php";
    $s=file_get_contents($f);
    if(!preg_match("~function\\s+create\\s*\\(~",$s)){
      // naive inject after class line
      $s=preg_replace("~class\\s+NetworksController[^{]*\\{~",
        "class NetworksController extends Controller {\\n    public function create(){\\n        \\\\App\\\\Models\\\\Country::query()->orderBy(\"name\")->get();\\n        \$network = new \\\\App\\\\Models\\\\Network;\\n        \$countries = \\\\App\\\\Models\\\\Country::orderBy(\"name\")->get();\\n        return view(\"networks.create\", compact(\"network\",\"countries\"));\\n    }\\n",
        $s,1);
    } else {
      // Patch existing to ensure it returns $network
      $s=preg_replace(
        "~function\\s+create\\s*\\([^)]*\\)\\s*\\{[\\s\\S]*?\\}~",
        "function create(){\\n    \$network = new \\\\App\\\\Models\\\\Network;\\n    \$countries = \\\\App\\\\Models\\\\Country::orderBy(\"name\")->get();\\n    return view(\"networks.create\", compact(\"network\",\"countries\"));\\n}",
        $s,1
      );
    }
    file_put_contents($f,$s);
  '
fi

# Do the same for countries create (pass $country) to be consistent
if [ -f "$CT_CTL" ]; then
  cp -a "$CT_CTL" "$CT_CTL.bak.$(date +%F_%H-%M-%S)"
  php -r '
    $f="app/Http/Controllers/CountriesController.php";
    if(!file_exists($f)) exit(0);
    $s=file_get_contents($f);
    if(!preg_match("~function\\s+create\\s*\\(~",$s)){
      $s=preg_replace("~class\\s+CountriesController[^{]*\\{~",
        "class CountriesController extends Controller {\\n    public function create(){\\n        \$country = new \\\\App\\\\Models\\\\Country;\\n        return view(\"countries.create\", compact(\"country\"));\\n    }\\n",
        $s,1);
    } else {
      $s=preg_replace(
        "~function\\s+create\\s*\\([^)]*\\)\\s*\\{[\\s\\S]*?\\}~",
        "function create(){\\n    \$country = new \\\\App\\\\Models\\\\Country;\\n    return view(\"countries.create\", compact(\"country\"));\\n}",
        $s,1
      );
    }
    file_put_contents($f,$s);
  '
fi

echo "==> 4) Show created/updated timestamps in both index pages"
# Overwrite the two index views with timestamp columns (compact, Tailwind)
cat > "$CN_IDX" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Countries</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
    <form method="GET" class="flex flex-wrap items-center gap-2">
      <input type="text" name="q" value="{{ request('q') }}" placeholder="Search name/MCC…" class="rounded border px-3 py-2">
      <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      <a href="{{ route('countries.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Country</a>
      @if (Route::has('countries.import'))
      <form method="POST" action="{{ route('countries.import') }}" class="inline">@csrf
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Refresh from sources</button>
      </form>
      @endif
    </form>

    <div class="overflow-x-auto">
      <table class="min-w-full text-sm">
        <thead>
          <tr class="text-left border-b">
            <th class="px-3 py-2">Name</th>
            <th class="px-3 py-2">ISO2</th>
            <th class="px-3 py-2">MCCs</th>
            <th class="px-3 py-2">Created</th>
            <th class="px-3 py-2">Updated</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($countries as $c)
            <tr class="border-b hover:bg-gray-50">
              <td class="px-3 py-2">{{ $c->name }}</td>
              <td class="px-3 py-2">{{ $c->iso2 }}</td>
              <td class="px-3 py-2">
                @foreach (($c->mccs ?? []) as $m)
                  <span class="inline-block rounded border px-2 py-0.5 text-xs mr-1">{{ $m->mcc }}</span>
                @endforeach
              </td>
              <td class="px-3 py-2 text-gray-500">{{ optional($c->created_at)->format('Y-m-d H:i') }}</td>
              <td class="px-3 py-2 text-gray-500">{{ optional($c->updated_at)->format('Y-m-d H:i') }}</td>
              <td class="px-3 py-2">
                <a href="{{ route('countries.edit',$c) }}" class="rounded border px-2 py-1 hover:bg-gray-100">Edit</a>
              </td>
            </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div>{{ $countries->withQueryString()->links() }}</div>
  </div>
</x-app-layout>
BLADE

cat > "$NW_IDX" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Networks</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
    <form method="GET" class="flex flex-wrap items-center gap-2">
      <input type="text" name="q" value="{{ request('q') }}" placeholder="Search name…" class="rounded border px-3 py-2">
      <input type="text" name="mcc" value="{{ request('mcc') }}" placeholder="MCC" class="rounded border px-3 py-2 w-24">
      <input type="text" name="mnc" value="{{ request('mnc') }}" placeholder="MNC" class="rounded border px-3 py-2 w-24">
      <input type="text" name="country" value="{{ request('country') }}" placeholder="Country" class="rounded border px-3 py-2">
      <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Filter</button>
      <a href="{{ route('networks.create') }}" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Add Network</a>
      @if (Route::has('networks.import'))
      <form method="POST" action="{{ route('networks.import') }}" class="inline">@csrf
        <button class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Refresh from sources</button>
      </form>
      @endif
    </form>

    <div class="overflow-x-auto">
      <table class="min-w-full text-sm">
        <thead>
          <tr class="text-left border-b">
            <th class="px-3 py-2">Name</th>
            <th class="px-3 py-2">MCC</th>
            <th class="px-3 py-2">MNC</th>
            <th class="px-3 py-2">MCC-MNC</th>
            <th class="px-3 py-2">Country</th>
            <th class="px-3 py-2">Created</th>
            <th class="px-3 py-2">Updated</th>
            <th class="px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          @foreach ($networks as $n)
            <tr class="border-b hover:bg-gray-50">
              <td class="px-3 py-2">{{ $n->name }}</td>
              <td class="px-3 py-2">{{ $n->mcc }}</td>
              <td class="px-3 py-2">{{ $n->mnc }}</td>
              <td class="px-3 py-2">{{ $n->mcc_mnc }}</td>
              <td class="px-3 py-2">{{ optional($n->country)->name }}</td>
              <td class="px-3 py-2 text-gray-500">{{ optional($n->created_at)->format('Y-m-d H:i') }}</td>
              <td class="px-3 py-2 text-gray-500">{{ optional($n->updated_at)->format('Y-m-d H:i') }}</td>
              <td class="px-3 py-2">
                <a href="{{ route('networks.edit',$n) }}" class="rounded border px-2 py-1 hover:bg-gray-100">Edit</a>
              </td>
            </tr>
          @endforeach
        </tbody>
      </table>
    </div>

    <div>{{ $networks->withQueryString()->links() }}</div>
  </div>
</x-app-layout>
BLADE

echo "==> 5) Drop a tiny offline MCC/MNC seed so 'Fresh import' yields visible rows (if remote is blocked)"
cat > "$SEED" <<'JSON'
{
  "version": 1,
  "countries": [
    {"name":"Greece","iso2":"GR","mccs":["202"]},
    {"name":"United States","iso2":"US","mccs":["310","311","312","313","314","315","316"]}
  ],
  "networks": [
    {"name":"COSMOTE","mcc":"202","mnc":"01"},
    {"name":"VODAFONE GR","mcc":"202","mnc":"05"},
    {"name":"NOVA (WIND)","mcc":"202","mnc":"10"},
    {"name":"AT&T","mcc":"310","mnc":"410"},
    {"name":"T-Mobile US","mcc":"310","mnc":"260"},
    {"name":"Verizon","mcc":"311","mnc":"480"}
  ]
}
JSON

echo "==> 6) Permissions (host + container) and cache"
chmod -R a+rwX storage bootstrap/cache || true
$DC exec -T app bash -lc 'chmod -R a+rwX storage bootstrap/cache || true'
$DC exec -T app bash -lc 'php artisan optimize:clear && php artisan route:cache && php artisan view:cache' || true

echo "==> Done."
