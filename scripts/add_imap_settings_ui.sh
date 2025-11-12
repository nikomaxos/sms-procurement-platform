#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

TS="$(date +%Y_%m_%d_%H%M%S)"

################################
# 0) Ensure dependency (v6)
################################
$DC exec -T app bash -lc 'composer show webklex/php-imap >/dev/null 2>&1 || composer require webklex/php-imap:^6 --no-interaction'

################################
# 1) Migration (singleton row)
################################
mkdir -p database/migrations
cat > "database/migrations/${TS}_create_imap_settings_table.php" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasTable('imap_settings')) {
            Schema::create('imap_settings', function (Blueprint $table) {
                $table->id();
                $table->string('host')->nullable();
                $table->unsignedInteger('port')->nullable();
                $table->enum('encryption', ['none','ssl','tls'])->default('ssl');
                $table->string('username')->nullable();
                $table->string('password')->nullable(); // NOTE: stored as-is for now
                $table->boolean('enabled')->default(false);
                $table->unsignedInteger('poll_minutes')->default(5);
                $table->json('selected_folders')->nullable();
                $table->json('last_folders_cache')->nullable();
                $table->text('last_test_log')->nullable();
                $table->timestamps();
            });
            // seed singleton row
            DB::table('imap_settings')->insert([
                'id' => 1,
                'host' => null,
                'port' => 993,
                'encryption' => 'ssl',
                'username' => null,
                'password' => null,
                'enabled' => false,
                'poll_minutes' => 5,
                'selected_folders' => json_encode([]),
                'last_folders_cache' => json_encode([]),
                'last_test_log' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        } else {
            // Add any missing columns if table already exists
            Schema::table('imap_settings', function (Blueprint $table) {
                if (!Schema::hasColumn('imap_settings','encryption')) $table->enum('encryption',['none','ssl','tls'])->default('ssl');
                if (!Schema::hasColumn('imap_settings','enabled')) $table->boolean('enabled')->default(false);
                if (!Schema::hasColumn('imap_settings','poll_minutes')) $table->unsignedInteger('poll_minutes')->default(5);
                if (!Schema::hasColumn('imap_settings','selected_folders')) $table->json('selected_folders')->nullable();
                if (!Schema::hasColumn('imap_settings','last_folders_cache')) $table->json('last_folders_cache')->nullable();
                if (!Schema::hasColumn('imap_settings','last_test_log')) $table->text('last_test_log')->nullable();
            });
        }
    }

    public function down(): void {
        Schema::dropIfExists('imap_settings');
    }
};
PHP

################################
# 2) Model
################################
mkdir -p app/Models
cat > app/Models/ImapSetting.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ImapSetting extends Model
{
    protected $table = 'imap_settings';
    protected $fillable = [
        'host','port','encryption','username','password',
        'enabled','poll_minutes','selected_folders','last_folders_cache','last_test_log'
    ];
    protected $casts = [
        'enabled' => 'boolean',
        'poll_minutes' => 'integer',
        'selected_folders' => 'array',
        'last_folders_cache' => 'array',
    ];

    public static function singleton(): self {
        return static::firstOrCreate(['id' => 1], []);
    }
}
PHP

################################
# 3) Controller
################################
mkdir -p app/Http/Controllers
cat > app/Http/Controllers/ImapSettingsController.php <<'PHP'
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
        $folders = $s->last_folders_cache ?? [];
        $log = $s->last_test_log;
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
            'poll_minutes' => ['required','integer','min:1','max:10080'], // minutes
            'selected_folders' => ['nullable','array'],
            'selected_folders.*' => ['string','max:255'],
        ]);

        if (!isset($data['password']) || $data['password']==='') {
            unset($data['password']); // do NOT clear if left blank
        }

        $data['enabled'] = (bool)($data['enabled'] ?? false);

        $s->fill($data);
        $s->save();

        return back()->with('status','saved');
    }

    public function test(Request $request) {
        $s = ImapSetting::singleton();
        $cfg = $this->imapConfig($s, $request);
        $log = [];

        try {
            $log[] = "Connecting to {$cfg['host']}:{$cfg['port']} ({$cfg['encryption']??'none'}) as {$cfg['username']}";
            $cm = new ClientManager();
            $client = $cm->make($cfg);
            $client->connect();
            $log[] = "Connected OK.";
            $client->disconnect();
            $log[] = "Disconnected.";
        } catch (\Throwable $e) {
            $log[] = "ERROR: ".$e->getMessage();
        }

        $s->last_test_log = implode("\n",$log);
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

            // v6 API; no children()
            $folders = $client->getFolders(false);
            foreach ($folders as $f) {
                $names[] = $f->full_name; // or $f->name; full_name is safer
            }
            sort($names, SORT_NATURAL | SORT_FLAG_CASE);

            $log[] = "Fetched ".count($names)." folder(s).";
            $client->disconnect();
        } catch (\Throwable $e) {
            $log[] = "ERROR: ".$e->getMessage();
        }

        $s->last_folders_cache = $names;
        $s->last_test_log = implode("\n",$log);
        $s->save();

        return back()->with('status','folders-fetched');
    }

    private function imapConfig(ImapSetting $s, Request $req): array {
        // when testing/fetching, allow using unsaved form values if provided
        $host = $req->input('host', $s->host);
        $port = (int)$req->input('port', $s->port ?: 993);
        $enc  = $req->input('encryption', $s->encryption ?: 'ssl');
        $user = $req->input('username', $s->username);
        $pass = $req->input('password', $s->password); // if left blank on UI, we keep stored

        if ($enc === 'none') $enc = null;

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

################################
# 4) View (Blade)
################################
mkdir -p resources/views/settings/imap
cat > resources/views/settings/imap/edit.blade.php <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">IMAP Settings</h2>
  </x-slot>

  <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
    @if (session('status'))
      <div class="mb-4 rounded border bg-green-50 text-green-800 px-4 py-2 text-sm">
        {{ session('status') }}
      </div>
    @endif

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <div class="md:col-span-2 bg-white border rounded-lg p-6">
        <form method="POST" action="{{ route('settings.imap.update') }}" class="space-y-4">
          @csrf
          @method('PUT')

          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Host</label>
              <input name="host" value="{{ old('host', $s->host) }}" class="mt-1 w-full rounded border px-3 py-2" autocomplete="off">
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Port</label>
              <input name="port" type="number" min="1" max="65535" value="{{ old('port', $s->port ?? 993) }}" class="mt-1 w-full rounded border px-3 py-2">
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Encryption</label>
              <select name="encryption" class="mt-1 w-full rounded border px-3 py-2">
                @php $enc = old('encryption', $s->encryption ?? 'ssl'); @endphp
                <option value="none" {{ $enc==='none' ? 'selected' : '' }}>None</option>
                <option value="ssl"  {{ $enc==='ssl'  ? 'selected' : '' }}>SSL</option>
                <option value="tls"  {{ $enc==='tls'  ? 'selected' : '' }}>TLS</option>
              </select>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Username</label>
              <input name="username" value="{{ old('username', $s->username) }}" class="mt-1 w-full rounded border px-3 py-2" autocomplete="off">
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Password</label>
              <input name="password" type="password" value="" placeholder="{{ $s->password ? '•••••• (saved)' : '' }}" class="mt-1 w-full rounded border px-3 py-2">
              <p class="text-xs text-gray-500 mt-1">Leave blank to keep existing password.</p>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="flex items-center gap-2">
              @php $enabled = old('enabled', $s->enabled ?? false); @endphp
              <input type="checkbox" name="enabled" value="1" {{ $enabled ? 'checked' : '' }}>
              <label class="text-sm text-gray-700">Fetching enabled</label>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Polling every (minutes)</label>
              <input name="poll_minutes" type="number" min="1" max="10080" value="{{ old('poll_minutes', $s->poll_minutes ?? 5) }}" class="mt-1 w-full rounded border px-3 py-2">
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Folders to monitor</label>
            @php
              $opts = $folders ?? [];
              $selected = collect(old('selected_folders', $s->selected_folders ?? []))->map(strval::class)->all();
            @endphp
            <select name="selected_folders[]" multiple size="10" class="mt-1 w-full rounded border px-3 py-2">
              @forelse ($opts as $f)
                <option value="{{ $f }}" {{ in_array((string)$f, $selected, true) ? 'selected' : '' }}>
                  {{ $f }}
                </option>
              @empty
                <option disabled>(No folders fetched yet)</option>
              @endforelse
            </select>
            <p class="text-xs text-gray-500 mt-1">Use “Fetch folders” first, then select one or more.</p>
          </div>

          <div class="flex items-center gap-3">
            <button class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save</button>
          </div>
        </form>
      </div>

      <div class="bg-white border rounded-lg p-6 space-y-3">
        <form method="POST" action="{{ route('settings.imap.test') }}" class="space-y-2">
          @csrf
          <input type="hidden" name="host" value="{{ old('host', $s->host) }}">
          <input type="hidden" name="port" value="{{ old('port', $s->port ?? 993) }}">
          <input type="hidden" name="encryption" value="{{ old('encryption', $s->encryption ?? 'ssl') }}">
          <input type="hidden" name="username" value="{{ old('username', $s->username) }}">
          <input type="hidden" name="password" value="{{ old('password', '') }}">
          <button class="w-full rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">Test connection</button>
        </form>

        <form method="POST" action="{{ route('settings.imap.fetch') }}" class="space-y-2">
          @csrf
          <input type="hidden" name="host" value="{{ old('host', $s->host) }}">
          <input type="hidden" name="port" value="{{ old('port', $s->port ?? 993) }}">
          <input type="hidden" name="encryption" value="{{ old('encryption', $s->encryption ?? 'ssl') }}">
          <input type="hidden" name="username" value="{{ old('username', $s->username) }}">
          <input type="hidden" name="password" value="{{ old('password', '') }}">
          <button class="w-full rounded bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Fetch folders</button>
        </form>

        <div class="pt-2">
          <label class="block text-sm font-medium text-gray-700">Last log</label>
          <pre class="mt-1 max-h-64 overflow-auto rounded border bg-gray-50 p-2 text-xs text-gray-800">{{ $log }}</pre>
        </div>
      </div>
    </div>
  </div>
</x-app-layout>
BLADE

################################
# 5) Routes
################################
routes="routes/web.php"
cp -a "$routes" "$routes.bak.$TS"

# If edit route exists already, just ensure update/test/fetch are present inside auth group.
# Append (idempotent) if missing.
add_block='
Route::middleware(["auth"])->group(function () {
    Route::get("/settings/imap", [\App\Http\Controllers\ImapSettingsController::class, "edit"])->name("settings.imap.edit");
    Route::put("/settings/imap", [\App\Http\Controllers\ImapSettingsController::class, "update"])->name("settings.imap.update");
    Route::post("/settings/imap/test", [\App\Http\Controllers\ImapSettingsController::class, "test"])->name("settings.imap.test");
    Route::post("/settings/imap/fetch", [\App\Http\Controllers\ImapSettingsController::class, "fetchFolders"])->name("settings.imap.fetch");
});'

if ! grep -q "settings.imap.update" "$routes"; then
  printf "\n%s\n" "$add_block" >> "$routes"
fi

################################
# 6) Cache/compile & perms
################################
$DC exec -T app bash -lc '
  set -e
  composer dump-autoload -o
  php artisan migrate --force
  php artisan optimize:clear || true
  php artisan view:clear || true
  php artisan view:cache || true
  php artisan route:cache || true
'

# host-side: make sure Blade cache is writable (prevents permission denied)
chmod -R ug+rwX storage bootstrap 2>/dev/null || true
find storage bootstrap -type d -exec chmod 775 {} \; 2>/dev/null || true

echo "==> IMAP Settings UI installed. Open /settings/imap"
