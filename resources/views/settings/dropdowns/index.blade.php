<x-app-layout>
    <x-slot name="header">
        <h2 class="section-title">{{ __('Settings') }}</h2>
        <p class="section-subtitle">{{ __('Administration & configuration') }}</p>
    </x-slot>

    <nav class="breadcrumb mb-4 text-sm text-gray-500">
        <a href="{{ route('settings.index') }}" class="hover:underline">{{ __('Settings') }}</a>
        <span class="mx-2">›</span>
        <span class="text-gray-700">{{ __('Drop-down menus') }}</span>
    </nav>

    <div class="tabs mb-6 flex gap-2">
        <a href="{{ route('settings.users.index') }}" class="tab">{{ __('Users') }}</a>
        <a href="{{ route('settings.dropdowns.index') }}" class="tab-active">{{ __('Drop-down menus') }}</a>
        <a href="{{ route('settings.logs.index') }}" class="tab">{{ __('Auth Logs') }}</a>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {{-- Route Types --}}
        <div class="category">
            <h3>{{ __('Route Type') }}</h3>
            <p>{{ __('Direct, HQ, SS7, SIM, Local Bypass') }}</p>

            <form method="POST" action="{{ route('settings.route-types.store') }}" class="mb-4">
                @csrf
                <div class="flex gap-2">
                    <input name="name" type="text" class="input w-full" placeholder="{{ __('Add new type…') }}">
                    <button class="btn-primary">{{ __('Add') }}</button>
                </div>
            </form>

            <div class="overflow-x-auto">
                <table class="table">
                    <tbody class="divide-y divide-gray-200">
                        @foreach($routeTypes as $item)
                        <tr>
                            <td class="py-2 pe-2 w-full">{{ $item->name }}</td>
                            <td class="py-2 pe-2">
                                <form method="POST" action="{{ route('settings.route-types.update', $item) }}" class="flex gap-2">
                                    @csrf @method('PUT')
                                    <input name="name" value="{{ $item->name }}" class="input" />
                                    <button class="btn-primary">{{ __('Save') }}</button>
                                </form>
                            </td>
                            <td class="py-2">
                                <form method="POST" action="{{ route('settings.route-types.destroy', $item) }}" onsubmit="return confirm('Delete?')">
                                    @csrf @method('DELETE')
                                    <button class="btn">{{ __('Delete') }}</button>
                                </form>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>

        {{-- Known Hops --}}
        <div class="category">
            <h3>{{ __('Known Hops') }}</h3>
            <p>{{ __('0-Hop, 1-Hop, 2-Hops, N-Hops') }}</p>

            <form method="POST" action="{{ route('settings.known-hops.store') }}" class="mb-4">
                @csrf
                <div class="flex gap-2">
                    <input name="name" type="text" class="input w-full" placeholder="{{ __('Add new hop…') }}">
                    <button class="btn-primary">{{ __('Add') }}</button>
                </div>
            </form>

            <div class="overflow-x-auto">
                <table class="table">
                    <tbody class="divide-y divide-gray-200">
                        @foreach($knownHops as $item)
                        <tr>
                            <td class="py-2 pe-2 w-full">{{ $item->name }}</td>
                            <td class="py-2 pe-2">
                                <form method="POST" action="{{ route('settings.known-hops.update', $item) }}" class="flex gap-2">
                                    @csrf @method('PUT')
                                    <input name="name" value="{{ $item->name }}" class="input" />
                                    <button class="btn-primary">{{ __('Save') }}</button>
                                </form>
                            </td>
                            <td class="py-2">
                                <form method="POST" action="{{ route('settings.known-hops.destroy', $item) }}" onsubmit="return confirm('Delete?')">
                                    @csrf @method('DELETE')
                                    <button class="btn">{{ __('Delete') }}</button>
                                </form>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>

        {{-- Charge Models --}}
        <div class="category">
            <h3>{{ __('Charge Model') }}</h3>
            <p>{{ __('Per Submit, Per Delivered') }}</p>

            <form method="POST" action="{{ route('settings.charge-models.store') }}" class="mb-4">
                @csrf
                <div class="flex gap-2">
                    <input name="name" type="text" class="input w-full" placeholder="{{ __('Add new model…') }}">
                    <button class="btn-primary">{{ __('Add') }}</button>
                </div>
            </form>

            <div class="overflow-x-auto">
                <table class="table">
                    <tbody class="divide-y divide-gray-200">
                        @foreach($chargeModels as $item)
                        <tr>
                            <td class="py-2 pe-2 w-full">{{ $item->name }}</td>
                            <td class="py-2 pe-2">
                                <form method="POST" action="{{ route('settings.charge-models.update', $item) }}" class="flex gap-2">
                                    @csrf @method('PUT')
                                    <input name="name" value="{{ $item->name }}" class="input" />
                                    <button class="btn-primary">{{ __('Save') }}</button>
                                </form>
                            </td>
                            <td class="py-2">
                                <form method="POST" action="{{ route('settings.charge-models.destroy', $item) }}" onsubmit="return confirm('Delete?')">
                                    @csrf @method('DELETE')
                                    <button class="btn">{{ __('Delete') }}</button>
                                </form>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</x-app-layout>
