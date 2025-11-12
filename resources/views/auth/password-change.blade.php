<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Change Password</h2>
  </x-slot>

  <div class="max-w-2xl">
    @if (session('status') === 'password-changed')
      <div class="mb-4 rounded border border-green-200 bg-green-50 text-green-800 px-4 py-2 text-sm">
        Password updated successfully.
      </div>
    @endif

    <form method="POST" action="{{ route('password.change.update') }}" class="space-y-6">
      @csrf
      @method('PUT')

      <div>
        <label for="current_password" class="block text-sm font-medium text-gray-700">Current password</label>
        <input id="current_password" name="current_password" type="password" required
               autocomplete="current-password"
               class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
        @error('current_password')
          <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
        @enderror
      </div>

      <div>
        <label for="password" class="block text-sm font-medium text-gray-700">New password</label>
        <input id="password" name="password" type="password" required
               autocomplete="new-password"
               class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
        @error('password')
          <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
        @enderror
      </div>

      <div>
        <label for="password_confirmation" class="block text-sm font-medium text-gray-700">Confirm new password</label>
        <input id="password_confirmation" name="password_confirmation" type="password" required
               autocomplete="new-password"
               class="mt-1 block w-full rounded border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
      </div>

      <div class="flex items-center gap-3">
        <button type="submit"
                class="inline-flex items-center rounded bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700 focus:outline-none">
          Update Password
        </button>
        <a href="{{ url()->previous() }}"
           class="text-sm text-gray-600 hover:text-gray-900">Cancel</a>
      </div>
    </form>
  </div>
</x-app-layout>
