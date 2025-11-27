<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Create Network
        </h2>
    </x-slot>

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
        @includeIf('partials.flash_log')

        @if ($errors->any())
            <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md text-sm">
                <div class="font-semibold mb-1">There were some problems with your input:</div>
                <ul class="list-disc list-inside space-y-0.5">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        <div class="bg-white shadow sm:rounded-lg p-6 space-y-6">
            <form method="POST" action="{{ route('networks.store') }}">
                @csrf

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                        <label for="country_id" class="block text-sm font-medium text-gray-700">
                            Country
                        </label>
                        <select
                            id="country_id"
                            name="country_id"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        >
                            <option value="">-- Select country --</option>
                            @foreach ($countries as $country)
                                <option
                                    value="{{ $country->id }}"
                                    @selected((int) old('country_id') === $country->id)
                                >
                                    {{ $country->name }} ({{ $country->iso2 }})
                                </option>
                            @endforeach
                        </select>
                        @error('country_id')
                            <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="name" class="block text-sm font-medium text-gray-700">
                            Name
                        </label>
                        <input
                            type="text"
                            id="name"
                            name="name"
                            value="{{ old('name', '') }}"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                            required
                        >
                        @error('name')
                            <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                <div class="mt-6 flex items-center justify-between gap-3">
                    <a
                        href="{{ route('networks.index') }}"
                        class="inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50"
                    >
                        Back to list
                    </a>

                    <button
                        type="submit"
                        class="inline-flex items-center rounded-md border border-transparent bg-green-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
                    >
                        Create
                    </button>
                </div>
            </form>
        </div>
    </div>
</x-app-layout>
