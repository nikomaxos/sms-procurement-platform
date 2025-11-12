#!/usr/bin/env bash
set -Eeuo pipefail

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

CTR="app/Http/Controllers/ImapSettingsController.php"
VIEW="resources/views/settings/imap/edit.blade.php"

echo "==> Update ImapSettingsController to store human-readable folder labels and unique values"
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

        $raw_list = is_array($s->last_folders_cache) ? $s->last_folders_cache : array();
        $folders = array();
        $i = 0;
        foreach ($raw_list as $item) {
            if (is_array($item) && isset($item['value'])) {
                $val = (string)$item['value'];
                $label = isset($item['label']) ? (string)$item['label'] : $this->humanLabel($val);
            } else {
                $val = (string)$item;
                $label = $this->humanLabel($val);
            }
            $folders[] = array('value' => $val, 'label' => $label);
            $i++;
        }

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
        $s->enabled = $request->has('enabled') ? (bool)$request->input('enabled') : false;

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
        $out = array();
        $seen = array();

        try {
            $cm = new ClientManager();
            $client = $cm->make($cfg);
            $client->connect();

            $folders = $client->getFolders(false);
            foreach ($folders as $f) {
                $raw = '';
                if (isset($f->path) && $f->path) { $raw = (string)$f->path; }
                elseif (isset($f->full_name) && $f->full_name) { $raw = (string)$f->full_name; }
                elseif (isset($f->fullName) && $f->fullName) { $raw = (string)$f->fullName; }
                else { $raw = (string)$f->name; }

                $val = $raw;                              // exact server path
                $label = $this->humanLabel($raw);         // pretty label with arrows

                if (!isset($seen[$val])) {
                    $out[] = array('value' => $val, 'label' => $label);
                    $seen[$val] = true;
                }
            }

            // Sort by pretty label
            usort($out, function($a,$b){
                $la = isset($a['label']) ? $a['label'] : '';
                $lb = isset($b['label']) ? $b['label'] : '';
                return strcasecmp($la, $lb);
            });

            $log .= 'Fetched '.count($out).' folder(s).'."\n";
            $client->disconnect();
        } catch (\Throwable $e) {
            $log .= 'ERROR: '.$e->getMessage()."\n";
        }

        $s->last_folders_cache = $out;   // store as [{value, label}, ...]
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

    private function humanLabel($raw) {
        $s = (string)$raw;
        // Replace common IMAP delimiters with arrows
        $s = str_replace('\\', '/', $s);
        $parts = preg_split('/[\/\.]+/', $s);
        if (!is_array($parts)) { return $s; }
        // Optionally hide leading INBOX if followed by something
        if (count($parts) > 1 && strtoupper($parts[0]) === 'INBOX') {
            array_shift($parts);
        }
        return implode(' → ', $parts);
    }
}
PHP

echo "==> Re-write IMAP view with blue buttons and pretty folder labels"
cat > "$VIEW" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">IMAP Settings</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm">
        {{ session('status') }}
      </div>
    @endif
    @if ($errors->any())
      <div class="mb-4 rounded border bg-red-50 text-red-800 px-4 py-2 text-sm">
        <ul class="list-disc ms-5">
          @foreach ($errors->all() as $error)
            <li>{{ $error }}</li>
          @endforeach
        </ul>
      </div>
    @endif

    @php
      $selected = old('selected_folders', is_array($s->selected_folders) ? $s->selected_folders : []);
      if (!is_array($selected)) { $selected = []; }
    @endphp

    <form method="POST" action="{{ route('settings.imap.update') }}" class="space-y-6">
      @csrf
      @method('PUT')

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Host</label>
          <input name="host" type="text" class="mt-1 w-full rounded border px-3 py-2"
                 value="{{ old('host', $s->host) }}">
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700">Port</label>
          <input name="port" type="number" min="1" max="65535" class="mt-1 w-full rounded border px-3 py-2"
                 value="{{ old('port', $s->port ?: 993) }}">
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700">Encryption</label>
          @php $enc = old('encryption', $s->encryption ?: 'ssl'); @endphp
          <select name="encryption" class="mt-1 w-full rounded border px-3 py-2">
            <option value="none" {{ $enc === 'none' ? 'selected' : '' }}>None</option>
            <option value="ssl"  {{ $enc === 'ssl'  ? 'selected' : '' }}>SSL</option>
            <option value="tls"  {{ $enc === 'tls'  ? 'selected' : '' }}>TLS</option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700">Username</label>
          <input name="username" type="text" class="mt-1 w-full rounded border px-3 py-2"
                 value="{{ old('username', $s->username) }}">
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700">Password <span class="text-gray-400">(leave blank to keep)</span></label>
          <input name="password" type="password" class="mt-1 w-full rounded border px-3 py-2" autocomplete="new-password">
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700">Polling every (minutes)</label>
          <input name="poll_minutes" type="number" min="1" max="10080" class="mt-1 w-full rounded border px-3 py-2"
                 value="{{ old('poll_minutes', $s->poll_minutes ?: 5) }}">
        </div>

        <div class="md:col-span-3">
          @php $enabled = old('enabled', $s->enabled ? 1 : 0); @endphp
          <label class="inline-flex items-center gap-2">
            <input type="checkbox" name="enabled" value="1" {{ $enabled ? 'checked' : '' }}>
            <span class="text-sm text-gray-700">Fetching enabled (start polling loop)</span>
          </label>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Monitor folders (multi-select)</label>
          <select name="selected_folders[]" multiple size="12" class="w-full rounded border px-2 py-2">
            @foreach ($folders as $opt)
              @php
                $val = is_array($opt) && isset($opt['value']) ? $opt['value'] : (string)$opt;
                $label = is_array($opt) && isset($opt['label']) ? $opt['label'] : $val;
                $isSelected = in_array($val, $selected, true);
              @endphp
              <option value="{{ $val }}" {{ $isSelected ? 'selected' : '' }}>
                {{ $label }}
              </option>
            @endforeach
          </select>
          <p class="text-xs text-gray-500 mt-2">Use Ctrl/⌘ or Shift to select multiple. Click “Fetch folders” to refresh.</p>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Test / Fetch log</label>
          <pre class="w-full rounded border bg-gray-50 p-3 text-xs whitespace-pre-wrap" style="min-height: 12rem">{{ $log }}</pre>
        </div>
      </div>

      <div class="flex items-center gap-3">
        <button type="submit"
                class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 focus:outline-none focus:ring"
        >Save settings</button>

        <button type="submit"
                formaction="{{ route('settings.imap.test') }}"
                formmethod="POST"
                class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 focus:outline-none focus:ring"
        >Test connection</button>

        <button type="submit"
                formaction="{{ route('settings.imap.fetch') }}"
                formmethod="POST"
                class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 focus:outline-none focus:ring"
        >Fetch folders</button>
        @csrf
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

echo "==> Fix permissions & rebuild caches"
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
echo "==> Done. Reload /settings/imap and re-fetch folders."
