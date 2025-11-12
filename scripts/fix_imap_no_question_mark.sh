#!/usr/bin/env bash
set -Eeuo pipefail

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

CTR="app/Http/Controllers/ImapSettingsController.php"
ROUTES="routes/web.php"

echo "==> Write ultra-conservative ImapSettingsController (no ?, ??, ?->, ? :)"
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
        $folders = is_array($s->last_folders_cache) ? $s->last_folders_cache : array();
        $log = $s->last_test_log ? $s->last_test_log : '';
        return view('settings.imap.edit', compact('s','folders','log'));
    }

    public function update(Request $request) {
        $s = ImapSetting::singleton();

        $data = $request->validate(array(
            'host' => array('nullable','string','max:255'),
            'port' => array('nullable','integer','min:1','max:65535'),
            'encryption' => array('required', Rule::in(array('none','ssl','tls'))),
            'username' => array('nullable','string','max:255'),
            'password' => array('nullable','string','max:4096'),
            'enabled' => array('nullable','boolean'),
            'poll_minutes' => array('required','integer','min:1','max:10080'),
            'selected_folders' => array('nullable','array'),
            'selected_folders.*' => array('string','max:255'),
        ));

        if (!isset($data['password']) || $data['password'] === '') {
            unset($data['password']);
        }

        $s->fill($data);

        if ($request->has('enabled')) {
            $s->enabled = (bool)$request->input('enabled');
        } else {
            $s->enabled = false;
        }

        if ($request->has('selected_folders') && is_array($request->input('selected_folders'))) {
            $s->selected_folders = array_values($request->input('selected_folders'));
        }

        $s->save();
        return back()->with('status', 'IMAP settings saved.');
    }

    public function test(Request $request) {
        $s = ImapSetting::singleton();
        $cfg = $this->buildRuntimeConfig($request, $s);

        $log = '';
        try {
            $cm = new ClientManager();
            $client = $cm->make($cfg);
            $client->connect();

            $encLabel = 'none';
            if (isset($cfg['encryption']) && $cfg['encryption']) { $encLabel = $cfg['encryption']; }

            $log .= 'Connected OK to '.$cfg['host'].':'.$cfg['port'].' ('.$encLabel.")\n";
            $client->disconnect();
        } catch (\Throwable $e) {
            $log .= 'ERROR: '.$e->getMessage()."\n";
        }

        $s->last_test_log = $log;
        $s->save();

        return back()->with('status', 'Test finished. See log.');
    }

    public function fetchFolders(Request $request) {
        $s = ImapSetting::singleton();
        $cfg = $this->buildRuntimeConfig($request, $s);

        $log = '';
        $names = array();

        try {
            $cm = new ClientManager();
            $client = $cm->make($cfg);
            $client->connect();

            $folders = $client->getFolders(false);
            foreach ($folders as $f) {
                $names[] = $f->name;
            }
            sort($names, SORT_NATURAL|SORT_FLAG_CASE);
            $log .= 'Fetched '.count($names).' folder(s).'."\n";

            $client->disconnect();
        } catch (\Throwable $e) {
            $log .= 'ERROR: '.$e->getMessage()."\n";
        }

        $s->last_folders_cache = $names;
        $s->last_test_log = $log;
        $s->save();

        return back()->with('status', 'Folders updated. See log.');
    }

    private function buildRuntimeConfig(Request $request, ImapSetting $s): array {
        $host = $s->host;
        if ($request->has('host')) { $host = (string)$request->input('host'); }

        $port = $s->port ? (int)$s->port : 993;
        if ($request->has('port')) { $port = (int)$request->input('port'); }

        $enc = $s->encryption ? (string)$s->encryption : 'ssl';
        if ($request->has('encryption')) { $enc = (string)$request->input('encryption'); }

        $username = $s->username;
        if ($request->has('username')) { $username = (string)$request->input('username'); }

        $password = $s->password;
        if ($request->filled('password')) { $password = (string)$request->input('password'); }

        $encryption = null;
        if ($enc !== 'none') { $encryption = $enc; }

        return array(
            'host'          => $host,
            'port'          => $port,
            'encryption'    => $encryption,
            'validate_cert' => true,
            'username'      => $username,
            'password'      => $password,
            'protocol'      => 'imap',
            'options'       => array('fetch_order' => 'newest'),
            'common_folders'=> false,
        );
    }
}
PHP

echo "==> Make sure Test/Fetch routes accept POST and PUT (idempotent)"
cp -a "$ROUTES" "$ROUTES.bak.$(date +%F_%H-%M-%S))"
perl -0777 -i -pe "s/^.*settings\\/imap\\/test.*\\n//mg; s/^.*settings\\/imap\\/fetch.*\\n//mg" "$ROUTES"
cat >> "$ROUTES" <<'PHP'

Route::middleware(['auth'])->group(function () {
    Route::match(['POST','PUT'], '/settings/imap/test',  [\App\Http\Controllers\ImapSettingsController::class, 'test'])->name('settings.imap.test');
    Route::match(['POST','PUT'], '/settings/imap/fetch', [\App\Http\Controllers\ImapSettingsController::class, 'fetchFolders'])->name('settings.imap.fetch');
});
PHP

echo "==> Fix perms & rebuild caches"
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
echo "==> Done. Try /settings/imap, then Test connection and Fetch folders."
