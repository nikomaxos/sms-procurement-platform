<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">Users</h2></x-slot>
    <div class="py-6">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8">
            <x-alert />
            <div class="bg-white p-6 shadow sm:rounded-lg">
                <div class="flex justify-between mb-4">
                    <div></div>
                    <a href="{{ route('admin.users.create') }}" class="px-4 py-2 bg-indigo-600 text-white rounded">New User</a>
                </div>
                <table class="w-full text-left">
                    <thead><tr class="border-b"><th class="py-2">ID</th><th>Name</th><th>Email</th><th>Admin</th><th class="text-right">Actions</th></tr></thead>
                    <tbody>
                        @foreach($users as $u)
                        <tr class="border-b">
                            <td class="py-2">{{ $u->id }}</td>
                            <td>{{ $u->name }}</td>
                            <td>{{ $u->email }}</td>
                            <td>{{ $u->is_admin ? 'Yes' : 'No' }}</td>
                            <td class="text-right">
                                <a class="px-3 py-1 bg-gray-100 rounded" href="{{ route('admin.users.edit',$u) }}">Edit</a>
                                @if(auth()->id() !== $u->id)
                                <form method="POST" action="{{ route('admin.users.destroy',$u) }}" class="inline" onsubmit="return confirm('Delete user?')">
                                    @csrf @method('DELETE')
                                    <button class="px-3 py-1 bg-red-600 text-white rounded">Delete</button>
                                </form>
                                @endif
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
                <div class="mt-4">{{ $users->links() }}</div>
            </div>
        </div>
    </div>
</x-app-layout>
