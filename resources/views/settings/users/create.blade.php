<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Add User</h2>
  </x-slot>

  <form method="POST" action="{{ route('settings.users.store') }}" class="max-w-2xl space-y-6">
    @csrf

    <div>
      <label class="block text-sm font-medium text-gray-700">Name</label>
      <input name="name" type="text" value="{{ old('name') }}" required
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
      @error('name')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">Email</label>
      <input name="email" type="email" value="{{ old('email') }}" required
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
      @error('email')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">Role</label>
      <select name="role" class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
        <option value="standard" {{ old('role','standard')==='standard'?'selected':'' }}>Standard</option>
        <option value="admin"    {{ old('role')==='admin'?'selected':'' }}>Admin</option>
      </select>
      @error('role')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">Password</label>
      <input name="password" type="password" required autocomplete="new-password"
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
      @error('password')<p class="text-sm text-red-600 mt-1">{{ $message }}</p>@enderror
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700">Confirm Password</label>
      <input name="password_confirmation" type="password" required autocomplete="new-password"
             class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
    </div>

    <div class="flex items-center gap-3">
      <button class="inline-flex items-center rounded bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700">Create</button>
      <a href="{{ route('settings.users.index') }}" class="text-sm text-gray-600 hover:text-gray-900">Cancel</a>
    </div>
  </form>
</x-app-layout>
