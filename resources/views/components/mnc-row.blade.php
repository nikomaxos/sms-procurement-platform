@props(['index'=>null,'m'=>null,'network'=>null])
@php
  $i = $index ?? ($loop->index ?? 0);
  $mnc = old("mncs.$i.mnc", $m->mnc ?? '');
  $mcc = $network->mcc ?? ($m->mcc ?? '');
  $mcc_mnc = ($mcc !== null && $mnc !== '') ? ($mcc.$mnc) : '';
@endphp
<div class="grid grid-cols-12 gap-2 items-center border-b py-2">
  <div class="col-span-3">
    <input name="mncs[{{ $i }}][mnc]" value="{{ $mnc }}" placeholder="MNC" class="w-full border rounded px-2 py-1">
  </div>
  <div class="col-span-3">
    <input value="{{ $mcc }}" class="w-full border rounded px-2 py-1 bg-gray-100" readonly>
  </div>
  <div class="col-span-4">
    <input value="{{ $mcc_mnc }}" class="w-full border rounded px-2 py-1 bg-gray-100" readonly>
  </div>
  <div class="col-span-2 text-right">
    <label class="inline-flex items-center gap-2">
      <input type="checkbox" name="mncs[{{ $i }}][remove]" value="1">
      <span>Remove</span>
    </label>
  </div>
</div>
