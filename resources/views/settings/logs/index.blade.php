<x-app-layout>
    <x-slot name="header">
        <h2 class="section-title">{{ __('Authentication Logs') }}</h2>
        <p class="section-subtitle">{{ __('Recent sign-ins and sign-outs') }}</p>
    </x-slot>

    <div class="card overflow-x-auto">
        <table class="min-w-full text-sm">
            <thead class="text-left text-gray-600">
                <tr>
                    <th class="py-2 pe-4">{{ __('When') }}</th>
                    <th class="py-2 pe-4">{{ __('User') }}</th>
                    <th class="py-2 pe-4">{{ __('Event') }}</th>
                    <th class="py-2 pe-4">{{ __('IP') }}</th>
                    <th class="py-2 pe-4">{{ __('User-Agent') }}</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
                @foreach($logs as $log)
                <tr>
                    <td class="py-2 pe-4 text-gray-800">{{ $log->created_at->format('Y-m-d H:i:s') }}</td>
                    <td class="py-2 pe-4">
                        @if($log->user)
                            <span class="font-medium text-gray-900">{{ $log->user->name }}</span>
                            <span class="text-gray-500">({{ $log->user->email }})</span>
                        @else
                            <span class="text-gray-500">—</span>
                        @endif
                    </td>
                    <td class="py-2 pe-4">
                        <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold
                            {{ $log->event === 'login' ? 'bg-green-100 text-green-800' : 'bg-amber-100 text-amber-800' }}">
                            {{ ucfirst($log->event) }}
                        </span>
                    </td>
                    <td class="py-2 pe-4 text-gray-700">{{ $log->ip ?? '—' }}</td>
                    <td class="py-2 pe-4 text-gray-500 max-w-[32rem] truncate" title="{{ $log->user_agent }}">{{ $log->user_agent }}</td>
                </tr>
                @endforeach
            </tbody>
        </table>

        <div class="mt-4">{{ $logs->links() }}</div>
    </div>
</x-app-layout>
