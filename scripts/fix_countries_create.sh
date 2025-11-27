#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(pwd)"
CTRL="app/Http/Controllers/CountriesController.php"
ROUTES="routes/web.php"
VIEW="resources/views/countries/create.blade.php"

BACKUP_DIR="${PROJECT_ROOT}/backup_countries_create_$(date +%F_%H-%M-%S)"
echo "==> Backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

echo "==> Backing up CountriesController.php"
cp "${CTRL}" "${BACKUP_DIR}/CountriesController.php"

# Flags: θα προσθέσουμε μόνο ό,τι λείπει
ADD_CREATE=1
ADD_SIMPLE=1

if grep -q "function create(" "${CTRL}"; then
  echo "==> create() already exists in CountriesController, will NOT add it."
  ADD_CREATE=0
fi

if grep -q "function storeSimple(" "${CTRL}"; then
  echo "==> storeSimple() already exists in CountriesController, will NOT add it."
  ADD_SIMPLE=0
fi

if [ "${ADD_CREATE}" -eq 0 ] && [ "${ADD_SIMPLE}" -eq 0 ]; then
  echo "==> Nothing to add in CountriesController."
else
  echo "==> Patching CountriesController.php (adding create()/storeSimple())"
  tmp="$(mktemp)"

  awk -v ADD_CREATE="${ADD_CREATE}" -v ADD_SIMPLE="${ADD_SIMPLE}" '
    { lines[NR]=$0 }
    END {
      last = NR
      for (i=1; i<=last; i++) {
        if (i == last) {
          if (ADD_CREATE == 1) {
            print "    /**";
            print "     * Show the form for creating a new country.";
            print "     */";
            print "    public function create()";
            print "    {";
            print "        \\$country = new \\\\App\\\\Models\\\\Country();";
            print "";
            print "        return view(\\'countries.create\\', compact(\\'country\\'));";
            print "    }";
            print "";
          }
          if (ADD_SIMPLE == 1) {
            print "    /**";
            print "     * Store a newly created country from the simple create form.";
            print "     */";
            print "    public function storeSimple(\\\\Illuminate\\\\Http\\\\Request \\$request)";
            print "    {";
            print "        \\$data = \\$request->validate([";
            print "            \\'name\\' => \\'required|string|max:255\\',";
            print "            \\'iso2\\' => \\'nullable|string|max:2\\',";
            print "        ]);";
            print "";
            print "        \\$country = new \\\\App\\\\Models\\\\Country();";
            print "        \\$country->name = \\$data[\\'name\\'];";
            print "        if (!empty(\\$data[\\'iso2\\'])) {";
            print "            \\$country->iso2 = strtoupper(\\$data[\\'iso2\\']);";
            print "        }";
            print "";
            print "        \\$country->save();";
            print "";
            print "        return redirect()";
            print "            ->route(\\'countries.index\\')";
            print "            ->with(\\'status\\', \\'Country created.\\');";
            print "    }";
            print "";
          }
        }
        print lines[i];
      }
    }
  ' "${CTRL}" > "${tmp}"

  mv "${tmp}" "${CTRL}"
fi

# Δημιουργία view για create αν δεν υπάρχει
if [ -f "${VIEW}" ]; then
  echo "==> View ${VIEW} already exists, NOT overwriting."
else
  echo "==> Creating ${VIEW}"
  mkdir -p "$(dirname "${VIEW}")"
  cat > "${VIEW}" << 'BLADE'
<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Create Country
        </h2>
    </x-slot>

    <div class="py-6 max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        @if (session('status'))
            <div class="mb-4 rounded-md bg-green-50 border border-green-200 text-green-800 text-sm px-4 py-3">
                {{ session('status') }}
            </div>
        @endif

        @if ($errors->any())
            <div class="mb-4 rounded-md bg-red-50 border border-red-200 text-red-800 text-sm px-4 py-3">
                <div class="font-semibold mb-1">
                    There were some problems with your input:
                </div>
                <ul class="list-disc pl-5 space-y-0.5">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        <div class="bg-white rounded-lg shadow px-6 py-5">
            <form method="POST" action="{{ route('countries.simple-store') }}" class="space-y-4">
                @csrf

                <div>
                    <label for="name" class="block text-sm font-medium text-gray-700">
                        Name
                    </label>
                    <input
                        type="text"
                        id="name"
                        name="name"
                        value="{{ old('name', $country->name ?? '') }}"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                        required
                    >
                </div>

                <div>
                    <label for="iso2" class="block text-sm font-medium text-gray-700">
                        ISO2 (optional)
                    </label>
                    <input
                        type="text"
                        id="iso2"
                        name="iso2"
                        value="{{ old('iso2', $country->iso2 ?? '') }}"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm uppercase"
                        maxlength="2"
                        placeholder="EG, GR, US"
                    >
                </div>

                <div class="flex justify-end gap-2 pt-2">
                    <a
                        href="{{ route('countries.index') }}"
                        class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
                    >
                        Cancel
                    </a>
                    <button
                        type="submit"
                        class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-semibold rounded-md shadow-sm text-white bg-green-500 hover:bg-green-600 focus:outline-none focus:ring-1 focus:ring-green-500 focus:ring-offset-1"
                    >
                        Save Country
                    </button>
                </div>
            </form>
        </div>
    </div>
</x-app-layout>
BLADE
fi

# Προσθήκη route για simple-store αν δεν υπάρχει
if grep -q "countries.simple-store" "${ROUTES}"; then
  echo "==> Route countries.simple-store already exists in ${ROUTES}, NOT adding."
else
  echo "==> Appending countries.simple-store route to ${ROUTES}"
  cat >> "${ROUTES}" << 'PHP'

Route::post('/countries/simple-store', [\App\Http\Controllers\CountriesController::class, 'storeSimple'])
    ->name('countries.simple-store')
    ->middleware('auth');
PHP
fi

echo "==> Done."
echo "   - Backup: ${BACKUP_DIR}"
echo "   - Controller: ${CTRL}"
echo "   - View: ${VIEW}"
echo "   - Routes updated: ${ROUTES}"
