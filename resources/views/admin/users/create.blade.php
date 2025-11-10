<x-app-layout>
<x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">New User</h2></x-slot>
<div class="py-6"><div class="max-w-2xl mx-auto sm:px-6 lg:px-8"><div class="bg-white p-6 shadow sm:rounded-lg">
    <form method="POST" action="{{ route('admin.users.store') }}" class="space-y-4">
        @csrf
        <div><label class="block">Name <input name="name" class="mt-1 w-full border rounded p-2" required></label></div>
        <div><label class="block">Email <input type="email" name="email" class="mt-1 w-full border rounded p-2" required></label></div>
        <div><label class="block">Password <input type="password" name="password" class="mt-1 w-full border rounded p-2" required></label></div>
        <div><label class="block">Confirm Password <input type="password" name="password_confirmation" class="mt-1 w-full border rounded p-2" required></label></div>
        <div class="flex items-center gap-2"><input type="checkbox" name="is_admin" value="1" id="is_admin"><label for="is_admin">Admin</label></div>
        <div class="pt-4"><button class="px-4 py-2 bg-indigo-600 text-white rounded">Save</button></div>
    </form>
</div></div></div>
</x-app-layout>
