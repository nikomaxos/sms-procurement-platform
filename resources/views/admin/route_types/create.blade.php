<x-app-layout>
  <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">New Route Types</h2></x-slot>
  <div class="py-6"><div class="max-w-xl mx-auto sm:px-6 lg:px-8"><div class="bg-white p-6 shadow sm:rounded-lg">
    <form method="POST" action="{{ route('admin/route_types.store') }}" class="space-y-4">
      @csrf
      <div><label class="block">Name<input name="name" class="mt-1 w-full border rounded p-2" required></label></div>
      <div class="pt-4"><button class="px-4 py-2 bg-indigo-600 text-white rounded">Save</button></div>
    </form>
  </div></div></div>
</x-app-layout>
