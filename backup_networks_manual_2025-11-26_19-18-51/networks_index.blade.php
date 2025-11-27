<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Networks
        </h2>
    </x-slot>

    @php
        $q         = $filters['q'] ?? '';
        $countryId = $filters['country_id'] ?? null;
        $perPage   = $filters['per_page'] ?? 20;
    @endphp

    <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
        @includeIf('partials.flash_log')

        {{-- Filters --}}
        <div class="bg-white p-4 rounded-lg shadow">
            <form method="GET" action="{{ route('networks.index') }}" class="grid grid-cols-1 md:grid-cols-3 gap-4 items-end">
                <div>
                    <label for="filter_q" class="block text-sm font-medium text-gray-700">
                        Name
                    </label>
                    <input
                        type="text"
                        id="filter_q"
                        name="q"
                        value="{{ $q }}"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        placeholder="Search by network name"
                    >
                </div>

                <div>
                    <label for="filter_country_id" class="block text-sm font-medium text-gray-700">
                        Country
                    </label>
                    <select
                        id="filter_country_id"
                        name="country_id"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                    >
                        <option value="">All</option>
                        @foreach($countries as $country)
                            <option value="{{ $country->id }}" @selected((string) $countryId === (string) $country->id)>
                                {{ $country->name }}
                            </option>
                        @endforeach
                    </select>
                </div>

                <div class="flex flex-wrap gap-2 justify-start md:justify-end">
                    <button
                        type="submit"
                        class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-semibold rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:ring-offset-1"
                    >
                        Apply filters
                    </button>
                    <a
                        href="{{ route('networks.index') }}"
                        class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                    >
                        Reset
                    </a>
                    <a
                        href="{{ route('networks.index', array_merge(request()->except('page'), ['export' => 'csv'])) }}"
                        class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                    >
                        Export CSV
                    </a>
                </div>
            </form>
        </div>

        {{-- Table + Create button --}}
        <div class="bg-white p-4 rounded-lg shadow">
            <div class="flex items-center justify-between mb-3">
                <h3 class="text-md font-semibold text-gray-800">
                    Results
                </h3>
                <a
                    href="{{ route('networks.create') }}"
                    class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-semibold rounded-md shadow-sm text-white bg-green-500 hover:bg-green-600"
                >
                    Create Network
                </a>
            </div>

            <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                    <thead class="bg-gray-50">
                        <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                            <th class="px-4 py-3">Name</th>
                            <th class="px-4 py-3">Country</th>
                            <th class="px-4 py-3">MCCs</th>
                            <th class="px-4 py-3 text-right">MNC count</th>
                            <th class="px-4 py-3 text-right">Actions</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200">
                        @forelse($networks as $network)
                            <tr>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    {{ $network->name }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    {{ optional($network->country)->name ?? '—' }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap">
                                    @php
                                        $mccs = $mccsMap[$network->id] ?? null;
                                    @endphp
                                    @if($mccs)
                                        @foreach(explode(',', $mccs) as $mcc)
                                            <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-gray-100 text-xs font-medium text-gray-800 mr-1">
                                                {{ $mcc }}
                                            </span>
                                        @endforeach
                                    @else
                                        <span class="text-xs text-gray-400">—</span>
                                    @endif
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-right text-xs">
                                    {{ $network->mncs_count ?? 0 }}
                                </td>
                                <td class="px-4 py-2 whitespace-nowrap text-right text-xs">
                                    <a
                                        href="{{ route('networks.edit', $network) }}"
                                        class="inline-flex items-center px-2 py-1 border border-gray-300 rounded-md bg-white text-gray-700 hover:bg-gray-50"
                                    >
                                        Edit
                                    </a>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="5" class="px-4 py-4 text-center text-sm text-gray-500">
                                    No networks found.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{-- Pagination + per-page selector --}}
            <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3 mt-3">
                <div>
                    {{ $networks->links() }}
                </div>
                <div class="flex items-center gap-2 text-xs">
                    <span class="text-gray-600">Results per page:</span>
                    <form method="GET" action="{{ route('networks.index') }}">
                        <input type="hidden" name="q" value="{{ $q }}">
                        <input type="hidden" name="country_id" value="{{ $countryId }}">
                        <select
                            name="per_page"
                            class="rounded-md border-gray-300 text-xs shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                            onchange="this.form.submit()"
                        >
                            @foreach([10, 25, 50, 100, 200] as $size)
                                <option value="{{ $size }}" @selected((int) $perPage === (int) $size)>{{ $size }}</option>
                            @endforeach
                        </select>
                    </form>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
