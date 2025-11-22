<x-app-layout>
    @section('content')
    <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <h1 class="text-2xl font-semibold text-gray-800 mb-4">
            Edit Supplier
        </h1>

        <form method="POST" action="{{ route('suppliers.update', $supplier) }}" class="space-y-6">
            @csrf
            @method('PUT')

            <div>
                <label for="name" class="block text-sm font-medium text-gray-700">Supplier Name</label>
                <input type="text"
                       name="name"
                       id="name"
                       value="{{ old('name', $supplier->name) }}"
                       required
                       class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                @error('name')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="email" class="block text-sm font-medium text-gray-700">Email Address</label>
                <input type="email"
                       name="email"
                       id="email"
                       value="{{ old('email', $supplier->email) }}"
                       class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">
                @error('email')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="notes" class="block text-sm font-medium text-gray-700">Notes</label>
                <textarea
                    name="notes"
                    id="notes"
                    rows="5"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm">{{ old('notes', $supplier->notes) }}</textarea>
                @error('notes')
                <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div class="flex justify-between items-center">
                <form action="{{ route('suppliers.destroy', $supplier) }}"
                      method="POST"
                      onsubmit="return confirm('Delete this supplier?');">
                    @csrf
                    @method('DELETE')
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-red-500 text-sm font-medium rounded-md text-red-700 bg-white hover:bg-red-50">
                        Delete
                    </button>
                </form>

                <div class="flex space-x-3">
                    <a href="{{ route('suppliers.index') }}"
                       class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                        Cancel
                    </a>
                    <button type="submit"
                            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                        Save changes
                    </button>
                </div>
            </div>
        </form>
    </div>
    @endsection
</x-app-layout>
