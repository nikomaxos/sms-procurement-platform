#!/usr/bin/env bash
set -Eeuo pipefail

LAY="resources/views/layouts/app.blade.php"
mkdir -p "$(dirname "$LAY")"

# Backup once per run
cp -a "$LAY" "${LAY}.bak.$(date +%F_%H-%M-%S)" 2>/dev/null || true

cat > "$LAY" <<'BLADE'
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ config('app.name', 'Laravel') }}</title>

    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.bunny.net">
    <link href="https://fonts.bunny.net/css?family=figtree:400,500,600&display=swap" rel="stylesheet" />

    <!-- Scripts (kept as-is; CSP-safe in your stack) -->
    @vite(['resources/css/app.css', 'resources/js/app.js'])
  </head>
  <body class="font-sans antialiased">
    @includeIf('partials.settings_nav')

    <div class="min-h-screen bg-gray-100">
      @includeIf('layouts.navigation')

      <!-- Header: support either @section('header') or $header -->
      @hasSection('header')
        <header class="bg-white shadow">
          <div class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
            @yield('header')
          </div>
        </header>
      @elseif(isset($header))
        <header class="bg-white shadow">
          <div class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
            {{ $header }}
          </div>
        </header>
      @endif

      <!-- Page Content: prefer @yield, but also render $slot if present -->
      <main>
        @yield('content')
        @isset($slot)
          {{ $slot }}
        @endisset
      </main>
    </div>
  </body>
</html>
BLADE

# Clear cached/compiled views inside the PHP container
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC exec -T app sh -lc '
  set -e
  mkdir -p storage/framework/{views,cache,sessions} storage/logs bootstrap/cache
  chown -R www-data:www-data storage bootstrap/cache || true
  chmod -R 0777 storage bootstrap/cache
  rm -f storage/framework/views/* || true
'
$DC exec -T -w /var/www/html app php artisan optimize:clear
$DC exec -T -w /var/www/html app php artisan view:cache || true
$DC exec -T -w /var/www/html app php artisan route:cache || true
$DC exec -T -w /var/www/html app php artisan config:cache || true

echo "Layout replaced with yield/slot compatibility and caches refreshed."
