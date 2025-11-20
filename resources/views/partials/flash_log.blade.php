@if (session('status'))
  <div class="mb-3 rounded border border-green-300 bg-green-50 p-3 text-green-800">
    {{ session('status') }}
  </div>
@endif
@if (session('error'))
  <div class="mb-3 rounded border border-red-300 bg-red-50 p-3 text-red-800">
    {{ session('error') }}
  </div>
@endif
@if (session('log'))
  <div class="mb-4 rounded border border-gray-300 bg-gray-50 p-3 text-gray-800">
    <div class="font-semibold mb-1">Log</div>
    <ul class="list-disc ml-5 text-sm">
      @foreach (session('log') as $line)
        <li>{{ $line }}</li>
      @endforeach
    </ul>
  </div>
@endif
