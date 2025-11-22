<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ config('app.name', 'Laravel') }}</title>
    @vite(['resources/css/app.css','resources/js/app.js'])
  </head>
  <body class="antialiased bg-gray-50">
    @include('partials.topbar')

    <div class="flex">
      @include('partials.sidebar')

      <main class="flex-1 min-h-screen">
        @isset($header)
          <header class="bg-white border-b">
            <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-4">
              {{ $header }}
            </div>
          </header>
        @endisset

        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6">
          @hasSection('content')
            @yield('content')
          @else
            {{ $slot ?? '' }}
          @endif
        </div>
      </main>
    </div>
  </body>
</html>
