<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Settings</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <a href="{{ route('settings.dropdowns.index') }}" class="block rounded-lg border p-6 bg-white hover:bg-gray-50">
        <div class="text-lg font-semibold">Drop Down Menus</div>
        <div class="text-gray-500 text-sm mt-1">Manage option lists used across the app.</div>
      </a>
      <a href="{{ route('settings.imap.edit') }}" class="block rounded-lg border p-6 bg-white hover:bg-gray-50">
        <div class="text-lg font-semibold">IMAP Settings</div>
        <div class="text-gray-500 text-sm mt-1">Configure mailbox polling (minutes) and folders.</div>
      </a>
      <a href="{{ route('settings.users.index') }}" class="block rounded-lg border p-6 bg-white hover:bg-gray-50">
        <div class="text-lg font-semibold">Users Management</div>
        <div class="text-gray-500 text-sm mt-1">List users (read-only stub; enhance later).</div>
      </a>
    </div>
  </div>
</x-app-layout>
