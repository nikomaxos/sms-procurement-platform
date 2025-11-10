<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl">Create User</h2></x-slot>
    <div class="p-6">
        <form method="POST" action="{{ route('settings.users.store') }}" class="space-y-4 max-w-xl">
            @csrf
            <div><label class="block">Name</label><input name="name" class="w-full border rounded p-2" required>@error('name')<div class="text-red-600 text-sm">{{ $message }}</div>@enderror</div>
            <div><label class="block">Email</label><input type="email" name="email" class="w-full border rounded p-2" required>@error('email')<div class="text-red-600 text-sm">{{ $message }}</div>@enderror</div>
            <div><label class="block">Password</label><input type="password" name="password" class="w-full border rounded p-2" required>@error('password')<div class="text-red-600 text-sm">{{ $message }}</div>@enderror</div>
            <label class="inline-flex items-center space-x-2"><input type="checkbox" name="is_admin" value="1"><span>Admin</span></label>
            <div class="pt-2"><button class="px-3 py-2 bg-blue-600 text-white rounded">Save</button><a href="{{ route('settings.users.index') }}" class="ml-2 underline">Cancel</a></div>
        </form>
    </div>
</x-app-layout>
