<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Users Management</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="rounded-lg border bg-white p-6 overflow-x-auto">
      <p class="text-gray-600 mb-4">Stub table (read-only). Replace with real management later.</p>
      <table class="min-w-full border">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 py-2 text-left text-sm font-semibold">ID</th>
            <th class="px-3 py-2 text-left text-sm font-semibold">Name</th>
            <th class="px-3 py-2 text-left text-sm font-semibold">Email</th>
            <th class="px-3 py-2 text-left text-sm font-semibold">Created</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          @foreach(\App\Models\User::select('id','name','email','created_at')->orderBy('id')->limit(20)->get() as $u)
            <tr>
              <td class="px-3 py-2 text-sm">{{ $u->id }}</td>
              <td class="px-3 py-2 text-sm">{{ $u->name }}</td>
              <td class="px-3 py-2 text-sm">{{ $u->email }}</td>
              <td class="px-3 py-2 text-sm">{{ $u->created_at }}</td>
            </tr>
          @endforeach
        </tbody>
      </table>
    </div>
  </div>
</x-app-layout>
