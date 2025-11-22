<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Edit Connection: {{ $connection->name }} ({{ $supplier->name }})
        </h2>
    </x-slot>

    <div class="py-6">
        <div class="max-w-3xl mx-auto sm:px-6 lg:px-8">
            <div class="bg-white overflow-hidden shadow-sm sm:rounded-lg">
                <div class="p-6 text-gray-900">
                    <form method="POST" action="{{ route('suppliers.connections.update', [$supplier, $connection]) }}" class="space-y-6">
                        @csrf
                        @method('PUT')

                        {{-- Connection Name --}}
                        <div>
                            <label for="name" class="block text-sm font-medium text-gray-700">
                                Connection Name
                            </label>
                            <input
                                id="name"
                                name="name"
                                type="text"
                                value="{{ old('name', $connection->name) }}"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                                required
                            />
                            @error('name')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Username --}}
                        <div>
                            <label for="username" class="block text-sm font-medium text-gray-700">
                                Username
                            </label>
                            <input
                                id="username"
                                name="username"
                                type="text"
                                value="{{ old('username', $connection->username) }}"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            />
                            @error('username')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Charge Type --}}
                        <div>
                            <label for="charge_type" class="block text-sm font-medium text-gray-700">
                                Charge Type
                            </label>
                            <select
                                id="charge_type"
                                name="charge_type"
                                class="mt-1 block w-full rounded-md border-gray-300 bg-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                                required
                            >
                                @php
                                    $currentChargeType = old('charge_type', $connection->charge_type);
                                @endphp
                                <option value="">-- Select Charge Type --</option>
                                <option value="per_submit" {{ $currentChargeType === 'per_submit' ? 'selected' : '' }}>
                                    Per Submit
                                </option>
                                <option value="per_delivered" {{ $currentChargeType === 'per_delivered' ? 'selected' : '' }}>
                                    Per Delivered
                                </option>
                            </select>
                            @error('charge_type')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        {{-- Product Type (dynamic from Drop Down Menus) --}}
                        <div>
                            <label for="product_type" class="block text-sm font-medium text-gray-700">
                                Product Type
                            </label>
                            @php
                                $currentProductType = old('product_type', $connection->product_type);
                            @endphp
                            <select
                                id="product_type"
                                name="product_type"
                                class="mt-1 block w-full rounded-md border-gray-300 bg-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            >
                                <option value="">-- Select Product Type --</option>
                                @forelse($productTypeOptions as $value => $label)
                                    <option value="{{ $value }}" {{ (string)$currentProductType === (string)$value ? 'selected' : '' }}>
                                        {{ $label }}
                                    </option>
                                @empty
                                    <option value="" disabled>-- No product types defined yet --</option>
                                @endforelse
                            </select>
                            @error('product_type')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror

                            @if(empty($productTypeOptions))
                                <p class="mt-2 text-xs text-gray-500">
                                    Define "Product Type" values under <strong>Settings → Drop Down Menus</strong>
                                    and they will automatically appear here.
                                </p>
                            @endif
                        </div>

                        {{-- Notes --}}
                        <div>
                            <label for="notes" class="block text-sm font-medium text-gray-700">
                                Notes
                            </label>
                            <textarea
                                id="notes"
                                name="notes"
                                rows="4"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            >{{ old('notes', $connection->notes) }}</textarea>
                            @error('notes')
                            <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        <div class="flex items-center justify-end gap-3">
                            <a href="{{ route('suppliers.show', $supplier) }}"
                               class="inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50">
                                Cancel
                            </a>

                            <button type="submit"
                                    class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                                Update Connection
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
