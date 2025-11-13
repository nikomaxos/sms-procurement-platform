@php
  $isEdit = isset($network) && $network->id;
  $mccVal = old('mcc', $network->mcc ?? '');
  $mncVal = old('mnc', $network->mnc ?? '');
  $keyVal = sprintf('%03s', preg_replace('/\D/','',$mccVal)) . sprintf('%03s', preg_replace('/\D/','',$mncVal));
@endphp
<div class="space-y-4">
  <div>
    <label class="block text-sm font-medium">Name</label>
    <input name="name" class="mt-1 w-full rounded border px-3 py-2" value="{{ old('name',$network->name ?? '') }}" required>
  </div>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <div>
      <label class="block text-sm font-medium">MCC</label>
      <input name="mcc" maxlength="3" class="mt-1 w-full rounded border px-3 py-2" value="{{ $mccVal }}" required>
    </div>
    <div>
      <label class="block text-sm font-medium">MNC</label>
      <input name="mnc" maxlength="3" class="mt-1 w-full rounded border px-3 py-2" value="{{ $mncVal }}" required>
    </div>
    <div>
      <label class="block text-sm font-medium">MCC-MNC (auto)</label>
      <input name="mcc_mnc_display" class="mt-1 w-full rounded border px-3 py-2 font-mono bg-gray-50" value="{{ $keyVal }}" readonly>
    </div>
  </div>
  <div>
    <label class="block text-sm font-medium">Country</label>
    <select name="country_id" class="mt-1 w-full rounded border px-3 py-2">
      <option value="">—</option>
      @foreach($countries as $c)
        <option value="{{ $c->id }}" @selected(old('country_id', $network->country_id ?? '')==$c->id)>{{ $c->name }}</option>
      @endforeach
    </select>
  </div>
</div>
<script>
document.addEventListener('DOMContentLoaded', ()=>{
  const mcc=document.querySelector('input[name="mcc"]');
  const mnc=document.querySelector('input[name="mnc"]');
  const out=document.querySelector('input[name="mcc_mnc_display"]');
  function pad3(s){ s=(s||'').replace(/\D/g,''); return s.padStart(3,'0').slice(0,3); }
  function refresh(){ out.value = pad3(mcc.value)+pad3(mnc.value); }
  mcc.addEventListener('input', refresh);
  mnc.addEventListener('input', refresh);
});
</script>
