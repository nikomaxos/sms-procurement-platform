<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between w-full">
            <h2 class="font-semibold text-xl text-gray-800 leading-tight">
                Offers
            </h2>

            {{-- Create Offer button --}}
            <a href="{{ route('offers.create') }}"
               class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-green-600 text-white hover:bg-green-700">
                + Create Offer
            </a>
        </div>
    </x-slot>

    {{-- FULL WIDTH PAGE --}}
    <div class="py-6 w-full max-w-full px-2 sm:px-4 lg:px-6 mx-auto">

        {{-- Status message --}}
        @if (session('status'))
            <div class="mb-4 bg-green-50 border border-green-200 text-green-800 px-4 py-3 rounded text-sm">
                {{ session('status') }}
            </div>
        @endif

        {{-- Filters --}}
        <div class="bg-white p-4 rounded-lg shadow mb-4 w-full">
            @include('offers.partials.filters')
        </div>

        {{-- TABLE WITH HORIZONTAL SCROLL --}}
        <div class="bg-white rounded-lg shadow overflow-x-auto w-full">
            @include('offers.partials.table')
        </div>
    </div>
</x-app-layout>
