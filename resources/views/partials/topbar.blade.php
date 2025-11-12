<header class="w-full border-b bg-white relative z-40">
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <div class="h-14 flex items-center justify-between">
      <a href="{{ url('/') }}" class="font-semibold text-gray-800">SMS Suppliers</a>

      <div class="flex items-center gap-4">
        @auth
          <div class="relative group">
            <button type="button" class="inline-flex items-center gap-2 text-sm text-gray-700 group-hover:text-gray-900">
              <span>{{ auth()->user()->name }}</span>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.17l3.71-3.94a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd"/></svg>
            </button>
            <div class="absolute right-0 mt-2 hidden group-hover:block bg-white border rounded-md shadow min-w-56 py-1">
              <a href="{{ route('password.change') }}" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50">Change Password</a>
              <form method="POST" action="{{ route('logout') }}">
                @csrf
                <button class="w-full text-left block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50">Logout</button>
              </form>
            </div>
          </div>
        @endauth

        @guest
          <a href="{{ route('login') }}" class="text-sm text-gray-700 hover:text-gray-900">Login</a>
        @endguest
      </div>
    </div>
  </div>
</header>
