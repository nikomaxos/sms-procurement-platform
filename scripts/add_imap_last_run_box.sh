#!/usr/bin/env bash
set -Eeuo pipefail

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

TS="$(date +%Y_%m_%d_%H%M%S)"

############################################
# 1) Migration: add last_run_at to settings
############################################
mkdir -p database/migrations
cat > "database/migrations/${TS}_add_last_run_at_to_imap_settings.php" <<'PHP'
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (Schema::hasTable('imap_settings') && !Schema::hasColumn('imap_settings','last_run_at')) {
            Schema::table('imap_settings', function (Blueprint $table) {
                $table->timestamp('last_run_at')->nullable()->after('last_test_log');
            });
        }
    }
    public function down(): void {
        if (Schema::hasTable('imap_settings') && Schema::hasColumn('imap_settings','last_run_at')) {
            Schema::table('imap_settings', function (Blueprint $table) {
                $table->dropColumn('last_run_at');
            });
        }
    }
};
PHP

############################################
# 2) Ensure model casts last_run_at
############################################
mkdir -p app/Models
cat > app/Models/ImapSetting.php <<'PHP'
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ImapSetting extends Model {
    protected $table = 'imap_settings';
    protected $guarded = [];
    protected $casts = [
        'enabled'            => 'bool',
        'selected_folders'   => 'array',
        'last_folders_cache' => 'array',
        'last_run_at'        => 'datetime',
    ];
    public static function singleton(): self {
        $m = static::find(1);
        if (!$m) { $m = new static(); $m->id = 1; $m->poll_minutes = 5; $m->save(); }
        return $m;
    }
}
PHP

############################################
# 3) Update Blade: show small "Last run" box
############################################
VIEW="resources/views/settings/imap/edit.blade.php"
mkdir -p "$(dirname "$VIEW")"
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
      $enabled = old('enabled', $s->enabled ? 1 : 0) ? true : false;
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
          <div class="flex flex-wrap items-center gap-3">
            <label class="inline-flex items-center gap-2">
              <input type="checkbox" name="enabled" value="1" {{ $enabled ? 'checked' : '' }}>
              <span class="text-sm text-gray-700">Fetching enabled (start polling loop)</span>
            </label>

            @if ($enabled)
              <div class="inline-flex items-center gap-2 text-xs rounded border bg-gray-50 px-2 py-1">
                <span class="text-gray-600">Last run:</span>
                <span class="font-medium text-gray-900">
                  @if ($s->last_run_at)
                    {{ $s->last_run_at->format('d/m/Y H:i') }}
                  @else
                    —
                  @endif
                </span>
              </div>
            @endif
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Monitor folders (multi-select)</label>
          <select name="selected_folders[]" multiple size="12" class="w-full rounded border px-2 py-2">
            @foreach (($folders ?? []) as $opt)
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

############################################
# 4) Migrate & rebuild caches; fix perms
############################################
$DC exec -T app bash -lc '
  set -e
  php artisan migrate --force
  php artisan optimize:clear || true
  php artisan view:clear || true
  php artisan view:cache || true
  php artisan route:cache || true
  chown -R www-data:www-data storage bootstrap/cache || true
'
echo "==> Done. Reload /settings/imap. When Enabled is ticked, the Last run box is shown (— until the poller sets it)."
