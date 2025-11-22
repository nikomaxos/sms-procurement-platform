<x-app-layout>
    @section('content')
    <div class="py-6 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        @if (session('status'))
            <div class="mb-4 text-sm text-green-600">
                {{ session('status') }}
            </div>
        @endif

        <div class="flex items-center justify-between mb-4">
            <h1 class="text-2xl font-semibold text-gray-800">
                Supplier: {{ $supplier->name }}
            </h1>
            <div class="flex space-x-2">
                <a href="{{ route('suppliers.index') }}"
                   class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm font-medium rounded-md bg-white text-gray-700 hover:bg-gray-50">
                    Back to list
                </a>
                <a href="{{ route('suppliers.edit', $supplier) }}"
                   class="inline-flex items-center px-3 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                    Edit Supplier
                </a>
            </div>
        </div>

        <div class="bg-white shadow-sm rounded-lg p-4 mb-6">
            <dl class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                <div>
                    <dt class="font-medium text-gray-500">Name</dt>
                    <dd class="text-gray-900">{{ $supplier->name }}</dd>
                </div>
                <div>
                    <dt class="font-medium text-gray-500">Email</dt>
                    <dd class="text-gray-900">{{ $supplier->email }}</dd>
                </div>
                <div class="md:col-span-2">
                    <dt class="font-medium text-gray-500">Notes</dt>
                    <dd class="text-gray-900 whitespace-pre-line">
                        {{ $supplier->notes }}
                    </dd>
                </div>
            </dl>
        </div>

        <div class="flex items-center justify-between mb-2">
            <h2 class="text-xl font-semibold text-gray-800">
                Connections
            </h2>
            <a href="{{ route('suppliers.connections.create', $supplier) }}"
               class="inline-flex items-center px-3 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm bg-blue-600 text-white hover:bg-blue-700">
                + New Connection
            </a>
        </div>

        <div class="bg-white shadow-sm rounded-lg overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50">
                    <tr>
                        <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Connection Name
                        </th>
                        <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Username
                        </th>
                        <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Charge Type
                        </th>
                        <th scope="col" class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Notes
                        </th>
                        <th scope="col" class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Actions
                        </th>
                    </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                    @forelse($supplier->connections as $connection)
                        <tr>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                {{ $connection->name }}
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                {{ $connection->username }}
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                                {{ $connection->charge_type_label }}
                            </td>
                            <td class="px-4 py-2 text-sm text-gray-500 max-w-md">
                                <div class="line-clamp-2">
                                    {{ $connection->notes }}
                                </div>
                            </td>
                            <td class="px-4 py-2 whitespace-nowrap text-right text-sm">
                                <a href="{{ route('suppliers.connections.edit', [$supplier, $connection]) }}"
                                   class="text-blue-600 hover:text-blue-900 mr-3">
                                    Edit
                                </a>
                                <form action="{{ route('suppliers.connections.destroy', [$supplier, $connection]) }}"
                                      method="POST"
                                      class="inline"
                                      onsubmit="return confirm('Delete this connection?');">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit"
                                            class="text-red-600 hover:text-red-800">
                                        Delete
                                    </button>
                                </form>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="px-4 py-4 text-center text-sm text-gray-500">
                                No connections yet for this supplier.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @endsection
</x-app-layout>
