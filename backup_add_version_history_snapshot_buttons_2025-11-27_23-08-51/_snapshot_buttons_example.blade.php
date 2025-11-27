{{-- 
  Version history snapshot UI helpers

  How to use:

  1) GLOBAL "Create backup" button:
     Place this form somewhere near the top of your Version History page.

  2) PER-ROW "Delete backup" button:
     Use inside your @foreach($snapshots as $snapshot) loop, replacing
     $snapshot['name'] with the actual identifier you use for the snapshot dir.
--}}

{{-- 1) Global create-backup button --}}
<form action="{{ route('version-history.snapshot') }}" method="POST" class="mb-4">
  @csrf
  <button
    type="submit"
    class="inline-flex items-center px-4 py-2 rounded-md bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
  >
    Create backup from current state
  </button>
</form>

{{-- 2) Per-record delete button example (inside your loop) --}}
{{--
@foreach($snapshots as $snapshot)
  <tr>
    <!-- your other columns here -->

    <td class="text-right space-x-2">
      <form
        action="{{ route('version-history.destroy', $snapshot['name']) }}"
        method="POST"
        class="inline-block"
        onsubmit="return confirm('Delete backup {{ $snapshot['name'] }} and all its files? This cannot be undone.');"
      >
        @csrf
        @method('DELETE')
        <button
          type="submit"
          class="inline-flex items-center px-3 py-1 rounded-md bg-red-600 text-white text-xs font-semibold hover:bg-red-700"
        >
          Delete
        </button>
      </form>
    </td>
  </tr>
@endforeach
--}}

