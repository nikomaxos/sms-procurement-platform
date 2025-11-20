@if (session('status'))
  <div class="mb-4 rounded border border-green-200 bg-green-50 p-3 text-green-800">
    {{ session('status') }}
  </div>
@endif

@if ($errors->any())
  <div class="mb-4 rounded border border-red-200 bg-red-50 p-3 text-red-800">
    <div class="font-semibold">Validation errors</div>
    <ul class="mt-2 list-disc list-inside">
      @foreach ($errors->all() as $error)
        <li>{{ $error }}</li>
      @endforeach
    </ul>
  </div>
@endif

@if (session('log'))
  <div class="mb-4 rounded border bg-gray-50 p-3">
    <div class="font-semibold text-gray-800">Log</div>
    <ul class="mt-2 space-y-1">
      @foreach (session('log') as $entry)
        @php $lvl = $entry['level'] ?? 'info'; @endphp
        <li class="@if($lvl==='error') text-red-700 @elseif($lvl==='success') text-green-700 @else text-gray-800 @endif">
          {{ $entry['msg'] ?? '' }}
        </li>
      @endforeach
    </ul>
  </div>
@endif
