@php /* expects: $network, $countries, $primaryMcc */ @endphp
<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div>
    <label class="block text-sm font-medium mb-1">Network name</label>
    <input name="name" value="{{ old('name', $network->name) }}" class="w-full rounded border px-3 py-2" required>
    <div class="text-xs text-gray-500 mt-1">Primary MCC: <b>{{ $primaryMcc ?: '—' }}</b></div>
  </div>

  <div>
    <label class="block text-sm font-medium mb-1">Country</label>
    <select name="country_id" class="w-full rounded border px-3 py-2" required>
      @foreach($countries as $c)
        <option value="{{ $c->id }}" {{ (int)old('country_id', $network->country_id) === $c->id ? 'selected' : '' }}>{{ $c->name }}</option>
      @endforeach
    </select>
  </div>

  <div class="md:col-span-2">
    <label class="block text-sm font-medium mb-2">MNCs</label>
    <div id="mnc-rows" class="space-y-2">
      @foreach(($network->mncs ?? collect()) as $m)
      <div class="flex flex-wrap items-center gap-2 mnc-row">
        <input type="hidden" name="mncs_existing[{{ $m->id }}][id]" value="{{ $m->id }}">
        <div>
          <div class="text-xs text-gray-500 mb-0.5">MNC</div>
          <input name="mncs_existing[{{ $m->id }}][mnc]" value="{{ $m->mnc }}" class="rounded border px-3 py-2 w-28" autocomplete="off">
        </div>
        <div>
          <div class="text-xs text-gray-500 mb-0.5">MCC-MNC</div>
          <input value="{{ ($m->mcc ?? $primaryMcc).$m->mnc }}" class="rounded border px-3 py-2 bg-gray-50 w-36" readonly>
        </div>
        <label class="ml-2 text-sm inline-flex items-center gap-1">
          <input type="checkbox" name="mncs_existing[{{ $m->id }}][delete]">
          remove
        </label>
        <div class="text-xs text-gray-500 ml-2">
          Created: {{ optional($m->created_at)->format('Y-m-d H:i') }}
          @if($m->created_by_user_id) by User #{{ $m->created_by_user_id }} @elseif($m->created_by_source) by {{ $m->created_by_source }} @endif
          • Updated: {{ optional($m->updated_at)->format('Y-m-d H:i') }}
          @if($m->updated_by_user_id) by User #{{ $m->updated_by_user_id }} @elseif($m->updated_by_source) by {{ $m->updated_by_source }} @endif
        </div>
      </div>
      @endforeach
    </div>

    <div class="mt-3 flex items-center gap-2">
      <input id="mnc-add" placeholder="Type MNC and press Enter" class="rounded border px-3 py-2 w-60" autocomplete="off">
      <span class="text-xs text-gray-500">Primary MCC: <b>{{ $primaryMcc ?: '—' }}</b></span>
    </div>
    <div id="mnc-new-container" class="mt-2 space-y-2"></div>

    <script>
    (function(){
      // quick-add MNC
      const input = document.getElementById('mnc-add');
      const cont  = document.getElementById('mnc-new-container');
      const primary = @json($primaryMcc ?? '');
      input.addEventListener('keydown', function(e){
        if(e.key === 'Enter'){
          e.preventDefault();
          const raw = (this.value || '').trim();
          if(!raw) return;
          const mnc = raw.replace(/\D+/g,'');
          if(!mnc) { this.value=''; return; }
          const row = document.createElement('div');
          row.className = 'flex flex-wrap items-center gap-2';
          const a = document.createElement('input');
          a.name = 'mncs_new[]';
          a.value = mnc;
          a.className = 'rounded border px-3 py-2 w-28';
          const b = document.createElement('input');
          b.readOnly = true;
          b.value = (primary||'') + mnc;
          b.className = 'rounded border px-3 py-2 bg-gray-50 w-36';
          row.appendChild(a); row.appendChild(b);
          cont.appendChild(row);
          this.value='';
        }
      });
    })();
    </script>
  </div>
</div>
