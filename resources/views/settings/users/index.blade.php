<x-app-layout>
  <x-slot name="header">
    <div class="flex items-center justify-between">
      <h2 class="font-semibold text-xl text-gray-800 leading-tight">Users Management</h2>
      <a href="{{ route('settings.users.create') }}"
         class="inline-flex items-center rounded bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Add User</a>
    </div>
  </x-slot>

  @if (session('status') === 'user-created')
    <div class="mb-4 rounded border border-green-200 bg-green-50 text-green-800 px-4 py-2 text-sm">User created.</div>
  @elseif (session('status') === 'user-updated')
    <div class="mb-4 rounded border border-green-200 bg-green-50 text-green-800 px-4 py-2 text-sm">User updated.</div>
  @elseif (session('status') === 'user-deleted')
    <div class="mb-4 rounded border border-green-200 bg-green-50 text-green-800 px-4 py-2 text-sm">User deleted.</div>
  @endif
  @if ($errors->any())
    <div class="mb-4 rounded border border-red-200 bg-red-50 text-red-800 px-4 py-2 text-sm">
      {{ $errors->first() }}
    </div>
  @endif

  <div class="bg-white border rounded">
    <div class="overflow-x-auto">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50 text-gray-600">
          <tr>
            <th class="px-4 py-2 text-left">ID</th>
            <th class="px-4 py-2 text-left">Name</th>
            <th class="px-4 py-2 text-left">Email</th>
            <th class="px-4 py-2 text-left">Role</th>
            <th class="px-4 py-2 text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          @foreach ($users as $u)
            <tr class="border-t">
              <td class="px-4 py-2">{{ $u->id }}</td>
              <td class="px-4 py-2">{{ $u->name }}</td>
              <td class="px-4 py-2">{{ $u->email }}</td>
              <td class="px-4 py-2">{{ ucfirst($u->role) }}</td>
              <td class="px-4 py-2 text-right">
                <a href="{{ route('settings.users.edit', $u) }}"
                   class="text-indigo-600 hover:text-indigo-800 mr-3">Edit</a>
                <form action="{{ route('settings.users.destroy', $u) }}" method="POST" class="inline"
                      onsubmit="return confirm('Delete this user?');">
                  @csrf @method('DELETE')
                  <button class="text-red-600 hover:text-red-800">Delete</button>
                </form>
              </td>
            </tr>
          @endforeach
        </tbody>
      </table>
    </div>
    <div class="px-4 py-3 border-t">
      {{ $users->links() }}
    </div>
  </div>
</x-app-layout>
