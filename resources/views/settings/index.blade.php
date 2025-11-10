<x-app-layout>
    <x-slot name="header">
        <h2 class="section-title">{{ __('Settings') }}</h2>
        <p class="section-subtitle">{{ __('Administration & configuration') }}</p>
    </x-slot>

    <nav class="breadcrumb mb-4 text-sm text-gray-500">
        <span class="text-gray-700">{{ __('Settings') }}</span>
    </nav>

    <div class="tabs mb-6 flex gap-2">
        <a href="{{ route('settings.users.index') }}" class="{{ request()->routeIs('settings.users.*') ? 'tab-active' : 'tab' }}">{{ __('Users') }}</a>
        <a href="{{ route('settings.dropdowns.index') }}" class="{{ request()->routeIs('settings.dropdowns.*') ? 'tab-active' : 'tab' }}">{{ __('Drop-down menus') }}</a>
        <a href="{{ route('settings.logs.index') }}" class="{{ request()->routeIs('settings.logs.*') ? 'tab-active' : 'tab' }}">{{ __('Auth Logs') }}</a>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <a href="{{ route('settings.users.index') }}" class="card hover:shadow transition">
            <h3 class="text-lg font-semibold">{{ __('User Management') }}</h3>
            <p class="text-gray-500 mt-1">{{ __('Create, edit and remove users; grant admin.') }}</p>
        </a>
        <a href="{{ route('settings.dropdowns.index') }}" class="card hover:shadow transition">
            <h3 class="text-lg font-semibold">{{ __('Drop-down menus') }}</h3>
            <p class="text-gray-500 mt-1">{{ __('Route Type, Known Hops, Charge Model') }}</p>
        </a>
        <a href="{{ route('settings.logs.index') }}" class="card hover:shadow transition">
            <h3 class="text-lg font-semibold">{{ __('Authentication Logs') }}</h3>
            <p class="text-gray-500 mt-1">{{ __('Recent sign-ins and sign-outs') }}</p>
        </a>
    </div>
</x-app-layout>
