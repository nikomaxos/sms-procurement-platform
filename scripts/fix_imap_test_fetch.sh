#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

CTR="app/Http/Controllers/ImapSettingsController.php"
VIEW="resources/views/settings/imap/edit.blade.php"
ROUTES="routes/web.php"

echo "==> Ensure ImapSetting model exists (singleton pattern)"
mkdir -p app/Models
if [ ! -f app/Models/ImapSetting.php ]; then
  cat > app/Models/ImapSetting.php <<'PHP'
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ImapSetting extends Model {
    protected $table = 'imap_settings';
    protected $guarded = [];
    protected $casts = [
        'enabled' => 'bool',
        'selected_folders' => 'array',
        'last_folders_cache' => 'array',
    ];
    public static function singleton(): self {
        $m = static::find(1);
        if (!$m) { $m = new static(); $m->id = 1; $m->poll_minutes = 5; $m->save(); }
        return $m;
    }
}
PHP
fi

echo "==> Rewrite controller to allow using unsaved form values for Test/Fetch"
mkdir -p "$(dirname "$CTR")"
cat > "$CTR" <<'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\ImapSetting;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Webklex\PHPIMAP\ClientManager;

class ImapSettingsController extends Controller
{
    public function __construct() { $this->middleware('auth'); }

    public function edit() {
        $s = ImapSetting::singleton();
        $folders = is_array($s->last_folders_cache) ? $s->last_folders_cache : [];
        $log = $s->last_test_log ?: '';
        return view('settings.imap.edit', compact('s','folders','log'));
    }

    public function update(Request $request) {
        $s = ImapSetting::singleton();
        $data = $request->validate([
            'host' => ['nullable','string','max:255'],
            'port' => ['nullable','integer','min:1','max:65535'],
            'encryption' => ['required', Rule::in(['none','ssl','tls'])],
            'username' => ['nullable','string','max:255'],
            'password' => ['nullable','string','max:4096'], // keep existing if blank
            'enabled' => ['nullable','boolean'],
            'poll_minutes' => ['required','integer','min:1','max:10080'],
            'selected_folders' => ['nullable','array'],
            'selected_folders.*' => ['string','max:255'],
        ]);

        // keep existing password when blank
        if (!isset($data['password']) || $data['password'] === '') unset($data['password']);

        $s->fill($data);
        if (isset($data['selected_folders'])) $s->selected_folders = array_values($data['selected_folders']);
        $s->save();

        return back()->with('status', 'IMAP settings saved.');
    }

    public function test(Request $request) {
        [$cfg, $s] = $this->mergedConfig($request);
        $log = '';
        try {
            $cm = new ClientManager();
            $client = $cm->make($cfg);
            $client->connect();
            $log .= "Connected OK to {$cfg['host']}:{$cfg['port']} ({$cfg['encryption'] ?: 'none'})\n";
            $client->disconnect();
        } catch (\Throwable $e) {
            $log .= "ERROR: ".$e->getMessage()."\n";
        }
        $s->last_test_log = $log; // store last test log for convenience
        $s->save();

        return back()->with('status', 'Test finished. See log.');
    }

    public function fetchFolders(Request $request) {
        [$cfg, $s] = $this->mergedConfig($request);
        $log = '';
        $names = [];
        try {
            $cm = new ClientManager();
            $client = $cm->make($cfg);
            $client->connect();
            foreach ($client->getFolders(false) as $f) { // false = non-recursive
                $names[] = $f->name;
            }
            sort($names, SORT_NATURAL|SORT_FLAG_CASE);
            $log .= "Fetched ".count($names)." folder(s).\n";
            $client->disconnect();
        } catch (\Throwable $e) {
            $log .= "ERROR: ".$e->getMessage()."\n";
        }
        $s->last_folders_cache = $names;
        $s->last_test_log = $log;
        $s->save();

        return back()->with('status', 'Folders updated. See log.');
    }

    /** Build a runtime IMAP config from request values (falling back to saved settings). */
    private function mergedConfig(Request $request): array {
        $s = ImapSetting::singleton();
        $host = $request->input('host', $s->host);
        $port = (int)($request->input('port', $s->port ?: 993));
        $enc  = $request->input('encryption', $s->encryption ?: 'ssl');
        $username = $request->input('username', $s->username);
        $password = $request->input('password', '') !== '' ? $request->input('password') : $s->password;

        $cfg = [
            'host'          => $host,
            'port'          => $port,
            'encryption'    => ($enc === 'none') ? null : $enc,
            'validate_cert' => true,
            'username'      => $username,
            'password'      => $password,
            'protocol'      => 'imap',
            'options'       => [
                'fetch_order' => 'newest', // harmless defaults
            ],
            'common_folders' => false,
        ];
        return [$cfg, $s];
    }
}
PHP

echo "==> Make Test/Fetch accept POST and PUT (single form has _method=PUT)"
cp -a "$ROUTES" "$ROUTES.bak.$(date +%F_%H-%M-%S)"

# Drop any previous test/fetch route lines; keep everything else intact
perl -0777 -i -pe "s/^.*settings\\/imap\\/test.*\\n//mg; s/^.*settings\\/imap\\/fetch.*\\n//mg" "$ROUTES"

cat >> "$ROUTES" <<'PHP'

Route::middleware(['auth'])->group(function () {
    // Save (PUT remains as-is elsewhere)
    // Test & Fetch: allow POST or PUT so they work from the single form with _method=PUT
    Route::match(['POST','PUT'], '/settings/imap/test',  [\App\Http\Controllers\ImapSettingsController::class, 'test'])->name('settings.imap.test');
    Route::match(['POST','PUT'], '/settings/imap/fetch', [\App\Http\Controllers\ImapSettingsController::class, 'fetchFolders'])->name('settings.imap.fetch');
});
PHP

echo "==> Ensure buttons are clearly styled in Blade"
if [ -f "$VIEW" ]; then
  # Add visible styles to the two secondary buttons (idempotent)
  perl -0777 -i -pe "s/bg-gray-700 px-4 py-2 text-white hover:bg-gray-800/bg-gray-700 border border-gray-800 px-4 py-2 text-white hover:bg-gray-800 focus:outline-none focus:ring/g" "$VIEW"
fi

echo "==> Fix permissions and rebuild caches"
chmod -R ug+rwX storage bootstrap 2>/dev/null || true
find storage bootstrap -type d -exec chmod 775 {} \; 2>/dev/null || true
$DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache || true'
$DC exec -T app bash -lc '
  set -e
  php artisan optimize:clear || true
  php artisan view:clear || true
  php artisan view:cache || true
  php artisan route:cache || true
'

echo "==> All set. Open /settings/imap, fill fields, click Test connection and Fetch folders without saving."
