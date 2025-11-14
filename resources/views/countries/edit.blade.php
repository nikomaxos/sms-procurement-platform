{{-- MCCS_NORMALIZER_ROUND19 --}}
@php
    // Normalize $mccs to a Collection regardless of what the controller passed.
    // Then prepare a safe, de-duplicated printable string.
    $mccs = collect($mccs ?? ($country->mccs ?? []));
    $mccs_list = $mccs->pluck('mcc')->filter()->unique()->values();
    $mccs_str = $mccs_list->implode(', ');
@endphp

<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800 leading-tight">Edit Country</h2></x-slot>
  <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="bg-white rounded-lg p-4 border space-y-3">
      <div><span class="font-medium">Country:</span> {{ $country->name }}</div>
      <div><span class="font-medium">ISO2:</span> {{ strtoupper($country->iso2) }}</div>
      <div><span class="font-medium">MCCs:</span> {{ $mccs->pluck('mcc')->implode(', ') }}</div>
    </div>
    <div class="mt-4">
      <a href="{{ route('countries.index') }}" class="rounded border px-4 py-2 bg-white hover:bg-gray-50">Back</a>
    </div>
  </div>
</x-app-layout>
