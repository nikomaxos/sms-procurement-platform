@props(['mnc'])

@php
    $mcc = str_pad((string)($mnc->mcc ?? ''), 3, '0', STR_PAD_LEFT);
    $mncCode = str_pad((string)($mnc->mnc ?? ''), 3, '0', STR_PAD_LEFT);
    $src = $mnc->updated_by_source ?? $mnc->created_by_source ?? null;
    $title = "MCC {$mcc} / MNC {$mncCode}" . ($src ? " — source: {$src}" : "");
@endphp

<span
  class="inline-flex items-center gap-1 px-2 py-0.5 rounded border bg-white text-gray-700 text-xs"
  title="{{ $title }}"
>
  <span class="font-mono">{{ $mcc }}-{{ $mncCode }}</span>
  @if($src)
    <span class="opacity-60">({{ $src }})</span>
  @endif
</span>
