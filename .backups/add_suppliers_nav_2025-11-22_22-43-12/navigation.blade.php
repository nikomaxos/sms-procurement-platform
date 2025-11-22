<nav x-data="{ open: false }" class="bg-white border-b border-gray-100">
    @php
        $user = auth()->user();
        $isAdmin = $user && (
            (!empty($user->is_admin)) ||
            (($user->usertype ?? null) === 'admin')
        );
    @endphp

    <!-- Primary Navigation Menu -->
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
            <div class="flex">
                <!-- Logo -->
                <div class="shrink-0 flex items-center">
                    <a href="{{ route('dashboard') }}">
                        <x-application-logo class="block h-9 w-auto fill-current text-gray-800" />
                    </a>
                </div>

                <!-- Navigation Links (left / basic menu) -->
                <div class="hidden space-x-8 sm:-my-px sm:ms-10 sm:flex items-center">
                    <x-nav-link :href="route('dashboard')" :active="request()->routeIs('dashboard')">
                        {{ __('Dashboard') }}
                    </x-nav-link>

                    <x-nav-link :href="route('countries.index')" :active="request()->routeIs('countries.*')">
                        {{ __('Countries') }}
                    </x-nav-link>

                    <x-nav-link :href="route('networks.index')" :active="request()->routeIs('networks.*')">
                        {{ __('Networks') }}
                    </x-nav-link>

                    <!-- Settings dropdown (hover) -->
                    @auth
                        <div
                            x-data="{ openSettings: false }"
                            @mouseenter="openSettings = true"
                            @mouseleave="openSettings = false"
                            class="relative flex items-center"
                        >
                            <x-nav-link href="#"
                                :active="request()->routeIs('settings.*') || request()->is('carriers/import') || request()->routeIs('users.*')">
                                <span class="inline-flex items-center">
                                    {{ __('Settings') }}
                                    <svg class="ms-1 h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"
                                         fill="currentColor" aria-hidden="true">
                                        <path fill-rule="evenodd"
                                              d="M5.23 7.21a.75.75 0 011.06.02L10 10.94l3.71-3.71a.75.75 0 111.06 1.06l-4.24 4.24a.75.75 0 01-1.06 0L5.21 8.27a.75.75 0 01.02-1.06z"
                                              clip-rule="evenodd" />
                                    </svg>
                                </span>
                            </x-nav-link>

                            <div
                                x-cloak
                                x-show="openSettings"
                                x-transition
                                class="absolute left-0 top-full mt-2 z-50 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5"
                            >
                                <div class="py-1 text-sm text-gray-700">
                                    <a href="{{ route('settings.dropdowns.index') }}" class="block px-4 py-2 hover:bg-gray-100">
                                        {{ __('Drop Down Menus') }}
                                    </a>
                                    <a href="{{ route('settings.imap.edit') }}" class="block px-4 py-2 hover:bg-gray-100">
                                        {{ __('IMAP Settings') }}
                                    </a>
                                    @if($isAdmin)
                                        <a href="{{ url('/carriers/import') }}" class="block px-4 py-2 hover:bg-gray-100">
                                            {{ __('Carriers Import') }}
                                        </a>

                                        @if (\Illuminate\Support\Facades\Route::has('users.index'))
                                            <a href="{{ route('users.index') }}" class="block px-4 py-2 hover:bg-gray-100">
                                                {{ __('Users Management') }}
                                            </a>
                                        @endif
                                    @endif
                                </div>
                            </div>
                        </div>
                    @endauth
                </div>
            </div>

            <!-- User Dropdown (top-right) -->
            <div class="hidden sm:flex sm:items-center sm:ms-6">
                <x-dropdown align="right" width="48">
                    <x-slot name="trigger">
                        <button
                            class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium
                                   rounded-md text-gray-500 bg-white hover:text-gray-700 focus:outline-none
                                   transition ease-in-out duration-150">
                            <div>{{ Auth::user()->name }}</div>

                            <div class="ms-1">
                                <svg class="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg"
                                     viewBox="0 0 20 20">
                                    <path fill-rule="evenodd"
                                          d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                                          clip-rule="evenodd" />
                                </svg>
                            </div>
                        </button>
                    </x-slot>

                    <x-slot name="content">
                        <x-dropdown-link :href="route('profile.edit')">
                            {{ __('Profile') }}
                        </x-dropdown-link>

                        <!-- Authentication -->
                        <form method="POST" action="{{ route('logout') }}">
                            @csrf

                            <x-dropdown-link :href="route('logout')"
                                onclick="event.preventDefault(); this.closest('form').submit();">
                                {{ __('Log Out') }}
                            </x-dropdown-link>
                        </form>
                    </x-slot>
                </x-dropdown>
            </div>

            <!-- Hamburger -->
            <div class="-me-2 flex items-center sm:hidden">
                <button @click="open = ! open"
                        class="inline-flex items-center justify-center p-2 rounded-md text-gray-400
                               hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:bg-gray-100
                               focus:text-gray-500 transition duration-150 ease-in-out">
                    <svg class="h-6 w-6" stroke="currentColor" fill="none" viewBox="0 0 24 24">
                        <path :class="{'hidden': open, 'inline-flex': ! open }" class="inline-flex"
                              stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                              d="M4 6h16M4 12h16M4 18h16" />
                        <path :class="{'hidden': ! open, 'inline-flex': open }" class="hidden"
                              stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                              d="M6 18L18 6M6 6l12 12" />
                    </svg>
                </button>
            </div>
        </div>
    </div>

    <!-- Responsive Navigation Menu (mobile) -->
    <div :class="{'block': open, 'hidden': ! open}" class="hidden sm:hidden">
        <div class="pt-2 pb-3 space-y-1">
            <x-responsive-nav-link :href="route('dashboard')" :active="request()->routeIs('dashboard')">
                {{ __('Dashboard') }}
            </x-responsive-nav-link>

            <x-responsive-nav-link :href="route('countries.index')" :active="request()->routeIs('countries.*')">
                {{ __('Countries') }}
            </x-responsive-nav-link>

            <x-responsive-nav-link :href="route('networks.index')" :active="request()->routeIs('networks.*')">
                {{ __('Networks') }}
            </x-responsive-nav-link>

            @auth
                <div class="border-t border-gray-200 mt-2 pt-2 space-y-1">
                    <span class="block px-4 py-2 text-xs font-semibold text-gray-500 uppercase">
                        {{ __('Settings') }}
                    </span>

                    <x-responsive-nav-link :href="route('settings.dropdowns.index')" :active="request()->routeIs('settings.dropdowns.*')">
                        {{ __('Drop Down Menus') }}
                    </x-responsive-nav-link>

                    <x-responsive-nav-link :href="route('settings.imap.edit')" :active="request()->routeIs('settings.imap.*')">
                        {{ __('IMAP Settings') }}
                    </x-responsive-nav-link>

                    @if($isAdmin)
                        <x-responsive-nav-link :href="url('/carriers/import')" :active="request()->is('carriers/import')">
                            {{ __('Carriers Import') }}
                        </x-responsive-nav-link>

                        @if (\Illuminate\Support\Facades\Route::has('users.index'))
                            <x-responsive-nav-link :href="route('users.index')" :active="request()->routeIs('users.*')">
                                {{ __('Users Management') }}
                            </x-responsive-nav-link>
                        @endif
                    @endif
                </div>
            @endauth
        </div>

        <!-- Responsive Settings Options -->
        <div class="pt-4 pb-1 border-t border-gray-200">
            <div class="px-4">
                <div class="font-medium text-base text-gray-800">{{ Auth::user()->name }}</div>
                <div class="font-medium text-sm text-gray-500">{{ Auth::user()->email }}</div>
            </div>

            <div class="mt-3 space-y-1">
                <x-responsive-nav-link :href="route('profile.edit')">
                    {{ __('Profile') }}
                </x-responsive-nav-link>

                <!-- Authentication -->
                <form method="POST" action="{{ route('logout') }}">
                    @csrf

                    <x-responsive-nav-link :href="route('logout')"
                        onclick="event.preventDefault(); this.closest('form').submit();">
                        {{ __('Log Out') }}
                    </x-responsive-nav-link>
                </form>
            </div>
        </div>
    </div>
</nav>
