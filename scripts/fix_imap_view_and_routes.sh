#!/usr/bin/env bash
set -Eeuo pipefail

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

VIEW="resources/views/settings/imap/edit.blade.php"
ROUTES="routes/web.php"

mkdir -p "$(dirname "$VIEW")"

echo "==> Write a clean IMAP Settings Blade view"
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
          <select name="encryption" class="mt-1 w-full rounded border px-3 py-2">
            @php $enc = old('encryption', $s->encryption ?: 'ssl'); @endphp
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
          <label class="inline-flex items-center gap-2">
            @php $enabled = old('enabled', $s->enabled ? 1 : 0); @endphp
            <input type="checkbox" name="enabled" value="1" {{ $enabled ? 'checked' : '' }}>
            <span class="text-sm text-gray-700">Fetching enabled (start polling loop)</span>
          </label>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Monitor folders (multi-select)</label>
          <select name="selected_folders[]" multiple size="10" class="w-full rounded border px-2 py-2">
            @foreach (($folders ?? []) as $f)
              @php $isSelected = in_array($f, $selected, true); @endphp
              <option value="{{ $f }}" {{ $isSelected ? 'selected' : '' }}>{{ $f }}</option>
            @endforeach
          </select>
          <p class="text-xs text-gray-500 mt-2">Use Ctrl/⌘ or Shift for multi-selection. Click “Fetch folders” to refresh the list.</p>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Test / Fetch log</label>
          <pre class="w-full rounded border bg-gray-50 p-3 text-xs whitespace-pre-wrap" style="min-height: 12rem">{{ $log }}</pre>
        </div>
      </div>

      <div class="flex items-center gap-3">
        <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">Save settings</button>

        <button type="submit"
                formaction="{{ route('settings.imap.test') }}"
                formmethod="POST"
                class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">
          Test connection
        </button>

        <button type="submit"
                formaction="{{ route('settings.imap.fetch') }}"
                formmethod="POST"
                class="rounded bg-gray-700 px-4 py-2 text-white hover:bg-gray-800">
          Fetch folders
        </button>
        @csrf
      </div>
    </form>
  </div>
</x-app-layout>
BLADE

echo "==> Ensure IMAP routes exist"
# Add update/test/fetch routes if missing
add_route() {
  local needle="$1"
  local block="$2"
  if ! grep -qF "$needle" "$ROUTES"; then
    printf "\n%s\n" "$block" >> "$ROUTES"
  fi
}

add_route "ImapSettingsController::class, 'update'" \
"Route::middleware(['auth'])->group(function () {
    Route::put('/settings/imap', [\\App\\Http\\Controllers\\ImapSettingsController::class, 'update'])->name('settings.imap.update');
});"

add_route "ImapSettingsController::class, 'test'" \
"Route::middleware(['auth'])->group(function () {
    Route::post('/settings/imap/test', [\\App\\Http\\Controllers\\ImapSettingsController::class, 'test'])->name('settings.imap.test');
});"

add_route "ImapSettingsController::class, 'fetchFolders'" \
"Route::middleware(['auth'])->group(function () {
    Route::post('/settings/imap/fetch', [\\App\\Http\\Controllers\\ImapSettingsController::class, 'fetchFolders'])->name('settings.imap.fetch');
});"

echo "==> Permissions for Blade cache"
chmod -R ug+rwX storage bootstrap 2>/dev/null || true
find storage bootstrap -type d -exec chmod 775 {} \; 2>/dev/null || true

if docker compose version >/dev/null 2>&1; then
  $DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache || true'
fi

echo "==> Clear & rebuild caches"
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
