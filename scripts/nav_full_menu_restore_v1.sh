#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TS="$(date +%F_%H-%M-%S)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$ROOT_DIR/logs"
BACKUP_ROOT="$ROOT_DIR/.backups"
BACKUP_DIR="$BACKUP_ROOT/nav_full_menu_${TS}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"
LOG_FILE="$LOG_DIR/nav_full_menu_${TS}.log"

echo "==> Running ${SCRIPT_NAME} at ${TS}" | tee "$LOG_FILE"
echo "ROOT_DIR:  $ROOT_DIR"            | tee -a "$LOG_FILE"
echo "LOG_FILE: $LOG_FILE"            | tee -a "$LOG_FILE"
echo "BACKUP:   $BACKUP_DIR"          | tee -a "$LOG_FILE"

# -------------------------------------------------------------------
# Helpers: backup + rollback
# -------------------------------------------------------------------
declare -a MOD_FILES=()

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    mkdir -p "$(dirname "$backup_path")" 2>/dev/null || true
    cp "$f" "$backup_path"
    MOD_FILES+=("$f")
    echo "==> Backed up $f -> $backup_path" | tee -a "$LOG_FILE"
  else
    echo "==> WARN: Tried to back up missing file $f" | tee -a "$LOG_FILE"
  fi
}

rollback() {
  echo "ERROR: ${SCRIPT_NAME} failed. Rolling back..." | tee -a "$LOG_FILE"
  for f in "${MOD_FILES[@]}"; do
    local rel="${f#"$ROOT_DIR/"}"
    local backup_path="${BACKUP_DIR}/${rel//\//_}"
    if [ -f "$backup_path" ]; then
      cp "$backup_path" "$f"
      echo "   - Restored $f from $backup_path" | tee -a "$LOG_FILE"
    else
      echo "   - No backup found for $f" | tee -a "$LOG_FILE"
    fi
  done
  echo "Rollback complete. See log: $LOG_FILE" | tee -a "$LOG_FILE"
  exit 1
}

trap rollback ERR

# -------------------------------------------------------------------
# Detect how to run artisan (docker vs host)
# -------------------------------------------------------------------
ARTISAN_CMD="php artisan"
if command -v docker &>/dev/null && [ -f "$ROOT_DIR/docker-compose.yml" ]; then
  # Prefer service name "app" (your compose file uses service: app)
  if docker compose ps app &>/dev/null; then
    ARTISAN_CMD="docker compose exec -T app php artisan"
    echo "==> Using artisan via docker compose (service: app)" | tee -a "$LOG_FILE"
  fi
fi

# -------------------------------------------------------------------
# 1) Rewrite layouts/navigation.blade.php with full top menu
# -------------------------------------------------------------------
NAV_FILE="$ROOT_DIR/resources/views/layouts/navigation.blade.php"
backup_file "$NAV_FILE"

cat > "$NAV_FILE" <<'BLADE'
<nav x-data="{ open: false }" class="bg-white border-b border-gray-100">
    <!-- Primary Navigation Menu -->
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
            <div class="flex">
                <!-- Logo -->
                <div class="shrink-0 flex items-center">
                    <a href="{{ route('dashboard') }}">
                        <x-application-logo class="block h-9 w-auto fill-current text-gray-800" />
                    </a>
                </div>

                <!-- Navigation Links (left / basic menu) -->
                <div class="hidden space-x-8 sm:-my-px sm:ms-10 sm:flex">
                    <x-nav-link :href="route('dashboard')" :active="request()->routeIs('dashboard')">
                        {{ __('Dashboard') }}
                    </x-nav-link>

                    <x-nav-link :href="route('countries.index')" :active="request()->routeIs('countries.*')">
                        {{ __('Countries') }}
                    </x-nav-link>

                    <x-nav-link :href="route('networks.index')" :active="request()->routeIs('networks.*')">
                        {{ __('Networks') }}
                    </x-nav-link>

                    @if(auth()->check() && auth()->user()->usertype === 'admin')
                        <x-nav-link :href="route('carriers.import')" :active="request()->routeIs('carriers.import')">
                            {{ __('Carriers Import') }}
                        </x-nav-link>
                    @endif
                </div>
            </div>

            <!-- User Dropdown (top-right) -->
            <div class="hidden sm:flex sm:items-center sm:ms-6">
                <x-dropdown align="right" width="48">
                    <x-slot name="trigger">
                        <button class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-gray-500 bg-white hover:text-gray-700 focus:outline-none transition ease-in-out duration-150">
                            <div>{{ Auth::user()->name }}</div>

                            <div class="ms-1">
                                <svg class="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                                </svg>
                            </div>
                        </button>
                    </x-slot>

                    <x-slot name="content">
                        <x-dropdown-link :href="route('profile.edit')">
                            {{ __('Profile') }}
                        </x-dropdown-link>

                        <!-- Authentication -->
                        <form method="POST" action="{{ route('logout') }}">
                            @csrf

                            <x-dropdown-link :href="route('logout')"
                                    onclick="event.preventDefault();
                                                this.closest('form').submit();">
                                {{ __('Log Out') }}
                            </x-dropdown-link>
                        </form>
                    </x-slot>
                </x-dropdown>
            </div>

            <!-- Hamburger -->
            <div class="-me-2 flex items-center sm:hidden">
                <button @click="open = ! open" class="inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:bg-gray-100 focus:text-gray-500 transition duration-150 ease-in-out">
                    <svg class="h-6 w-6" stroke="currentColor" fill="none" viewBox="0 0 24 24">
                        <path :class="{'hidden': open, 'inline-flex': ! open }" class="inline-flex" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
                        <path :class="{'hidden': ! open, 'inline-flex': open }" class="hidden" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                </button>
            </div>
        </div>
    </div>

    <!-- Responsive Navigation Menu (mobile) -->
    <div :class="{'block': open, 'hidden': ! open}" class="hidden sm:hidden">
        <div class="pt-2 pb-3 space-y-1">
            <x-responsive-nav-link :href="route('dashboard')" :active="request()->routeIs('dashboard')">
                {{ __('Dashboard') }}
            </x-responsive-nav-link>

            <x-responsive-nav-link :href="route('countries.index')" :active="request()->routeIs('countries.*')">
                {{ __('Countries') }}
            </x-responsive-nav-link>

            <x-responsive-nav-link :href="route('networks.index')" :active="request()->routeIs('networks.*')">
                {{ __('Networks') }}
            </x-responsive-nav-link>

            @if(auth()->check() && auth()->user()->usertype === 'admin')
                <x-responsive-nav-link :href="route('carriers.import')" :active="request()->routeIs('carriers.import')">
                    {{ __('Carriers Import') }}
                </x-responsive-nav-link>
            @endif
        </div>

        <!-- Responsive Settings Options -->
        <div class="pt-4 pb-1 border-t border-gray-200">
            <div class="px-4">
                <div class="font-medium text-base text-gray-800">{{ Auth::user()->name }}</div>
                <div class="font-medium text-sm text-gray-500">{{ Auth::user()->email }}</div>
            </div>

            <div class="mt-3 space-y-1">
                <x-responsive-nav-link :href="route('profile.edit')">
                    {{ __('Profile') }}
                </x-responsive-nav-link>

                <!-- Authentication -->
                <form method="POST" action="{{ route('logout') }}">
                    @csrf

                    <x-responsive-nav-link :href="route('logout')"
                            onclick="event.preventDefault();
                                        this.closest('form').submit();">
                        {{ __('Log Out') }}
                    </x-responsive-nav-link>
                </form>
            </div>
        </div>
    </div>
</nav>
BLADE

echo "==> navigation.blade.php rewritten." | tee -a "$LOG_FILE"

# -------------------------------------------------------------------
# 2) Clear & cache views (best-effort)
# -------------------------------------------------------------------
echo "==> Clearing and caching views..." | tee -a "$LOG_FILE"
$ARTISAN_CMD view:clear  2>&1 | tee -a "$LOG_FILE" || true
$ARTISAN_CMD view:cache  2>&1 | tee -a "$LOG_FILE" || true

echo "==> ${SCRIPT_NAME} completed successfully." | tee -a "$LOG_FILE"
echo "Log file:   $LOG_FILE" | tee -a "$LOG_FILE"
echo "Backups in: $BACKUP_DIR" | tee -a "$LOG_FILE"

