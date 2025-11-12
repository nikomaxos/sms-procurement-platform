#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

CTR="app/Http/Controllers/ImapSettingsController.php"
VIEW="resources/views/settings/imap/edit.blade.php"

echo "==> Rewrite ImapSettingsController with conservative syntax"
cat > "$CTR" <<'PHP'
<?php

namespace App\Http\Controllers;

use App\Models\ImapSetting;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Webklex\PHPIMAP\ClientManager;

class ImapSettingsController extends Controller
{
    public function __construct() {
        $this->middleware('auth');
    }

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

        if (!isset($data['password']) || $data['password'] === '') {
            unset($data['password']); // preserve existing
        }

        $data['enabled'] = !empty($data['enabled']);

        $s->fill($data);
        $s->save();

        return back()->with('status','saved');
    }

    public function test(Request $request) {
        $s = ImapSetting::singleton();
        $cfg = $this->imapConfig($s, $request);
        $log = [];

        try {
            $log[] = "Connecting to {$cfg['host']}:{$cfg['port']} (".($cfg['encryption'] ?: 'none').") as {$cfg['username']}";
            $cm = new ClientManager();
            $client = $cm->make($cfg);
            $client->connect();
            $log[] = "Connected OK.";
            $client->disconnect();
            $log[] = "Disconnected.";
        } catch (\Throwable $e) {
            $log[] = "ERROR: ".$e->getMessage();
        }

        $s->last_test_log = implode("\n", $log);
        $s->save();

        return back()->with('status','tested');
    }

    public function fetchFolders(Request $request) {
        $s = ImapSetting::singleton();
        $cfg = $this->imapConfig($s, $request);
        $names = [];
        $log = [];

        try {
            $log[] = "Connecting for folder listing…";
            $cm = new ClientManager();
            $client = $cm->make($cfg);
            $client->connect();

            $folders = $client->getFolders(false);
            foreach ($folders as $f) {
                // be defensive about property names across versions
                if (is_object($f)) {
                    if (property_exists($f, 'full_name')) {
                        $names[] = (string)$f->full_name;
                    } elseif (property_exists($f, 'name')) {
                        $names[] = (string)$f->name;
                    } else {
                        $names[] = (string)method_exists($f, '__toString') ? (string)$f : 'Unknown';
                    }
                }
            }
            sort($names, SORT_NATURAL | SORT_FLAG_CASE);

            $log[] = "Fetched ".count($names)." folder(s).";
            $client->disconnect();
        } catch (\Throwable $e) {
            $log[] = "ERROR: ".$e->getMessage();
        }

        $s->last_folders_cache = $names;
        $s->last_test_log = implode("\n", $log);
        $s->save();

        return back()->with('status','folders-fetched');
    }

    private function imapConfig(ImapSetting $s, Request $req): array {
        $host = $req->input('host', $s->host);
        $port = (int)($req->input('port', $s->port ?: 993));
        $enc  = $req->input('encryption', $s->encryption ?: 'ssl');
        $user = $req->input('username', $s->username);
        $pass = $req->input('password', $s->password);

        if ($enc === 'none') { $enc = null; }

        return [
            'host'          => $host,
            'port'          => $port,
            'encryption'    => $enc,
            'validate_cert' => true,
            'username'      => $user,
            'password'      => $pass,
            'protocol'      => 'imap',
        ];
    }
}
PHP

echo "==> Patch Blade view to avoid 'strval::class' usage"
if [ -f "$VIEW" ]; then
  perl -0777 -i -pe "s/collect\\(old\\('selected_folders',\\s*\\\$s->selected_folders\\s*\\?\\?\\s*\\[\\]\\)\\)->map\\(strval::class\\)->all\\(\\);/collect(old('selected_folders', \$s->selected_folders ?: []))->map(function(\$v){ return (string)\$v; })->all();/s" "$VIEW" || true
fi

echo "==> Fix permissions so Blade can write compiled views"
chmod -R ug+rwX storage bootstrap 2>/dev/null || true
find storage bootstrap -type d -exec chmod 775 {} \; 2>/dev/null || true
if docker compose version >/dev/null 2>&1; then
  $DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache || true'
fi

echo "==> Rebuild caches"
if docker compose version >/dev/null 2>&1; then
  $DC exec -T app bash -lc '
    set -e
    php artisan optimize:clear || true
    php artisan view:clear || true
    php artisan view:cache || true
    php artisan route:cache || true
  '
fi

echo "==> Done. Open /settings/imap"
