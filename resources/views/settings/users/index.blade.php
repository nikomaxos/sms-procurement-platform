<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between">
            <h2 class="font-semibold text-xl">Users</h2>
            <a href="{{ route('settings.users.create') }}" class="px-3 py-2 bg-blue-600 text-white rounded">New User</a>
        </div>
    </x-slot>
    <div class="p-6">
        @if (session('status')) <div class="mb-4 text-green-600">{{ session('status') }}</div> @endif
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead><tr class="text-left border-b">
                    <th class="py-2 pr-4">ID</th><th class="py-2 pr-4">Name</th><th class="py-2 pr-4">Email</th><th class="py-2 pr-4">Admin</th><th class="py-2 pr-4">Actions</th>
                </tr></thead>
                <tbody>
                @foreach($users as $u)
                    <tr class="border-b">
                        <td class="py-2 pr-4">{{ $u->id }}</td>
                        <td class="py-2 pr-4">{{ $u->name }}</td>
                        <td class="py-2 pr-4">{{ $u->email }}</td>
                        <td class="py-2 pr-4">{{ $u->is_admin ? 'Yes' : 'No' }}</td>
                        <td class="py-2 pr-4 space-x-2">
                            <a class="text-blue-600 underline" href="{{ route('settings.users.edit',$u) }}">Edit</a>
                            <form action="{{ route('settings.users.destroy',$u) }}" method="POST" class="inline" onsubmit="return confirm('Delete user?')">
                                @csrf @method('DELETE')
                                <button class="text-red-600 underline">Delete</button>
                            </form>
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
            <div class="mt-4">{{ $users->links() }}</div>
        </div>
    </div>
</x-app-layout>
