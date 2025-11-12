#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

SIDEBAR="resources/views/partials/sidebar.blade.php"
ALTNAV="resources/views/partials/nav.blade.php"
ERR403="resources/views/errors/403.blade.php"
CTR="app/Http/Controllers/Settings/UsersManagementController.php"

echo "==> 1) Ensure controller denies non-admin with a clean 403"
if [ -f "$CTR" ]; then
  # Harden the guard to be null-safe just in case
  perl -0777 -i -pe "s/abort_unless\\(\\$u && \\$u->role === 'admin', 403\\);/abort_unless((\\$u?->role ?? 'standard') === 'admin', 403);/s" "$CTR" || true
fi

echo "==> 2) Create a friendly 403 page (Blade)"
mkdir -p "$(dirname "$ERR403")"
cat > "$ERR403" <<'BLADE'
@extends('layouts.app')

@section('content')
  <div class="max-w-xl mx-auto mt-16 bg-white border rounded-lg p-6">
    <h1 class="text-2xl font-semibold text-gray-800 mb-2">403 — Δεν έχετε δικαίωμα πρόσβασης</h1>
    <p class="text-gray-600 mb-6">
      Δεν έχετε πρόσβαση στη διαχείριση χρηστών. Αν χρειάζεστε δικαιώματα διαχειριστή, επικοινωνήστε με τον υπεύθυνο του συστήματος.
    </p>
    <a href="{{ route('settings.index') }}"
       class="inline-block px-4 py-2 rounded bg-blue-600 text-white hover:bg-blue-700">
      Επιστροφή στις Ρυθμίσεις
    </a>
  </div>
@endsection
BLADE

echo "==> 3) Hide the 'Users Management' link for non-admins in sidebar (if present)"
if [ -f "$SIDEBAR" ]; then
  # Route-shaped link -> wrap with admin guard if not already wrapped
  if grep -q "route('settings.users.index')" "$SIDEBAR"; then
    if ! perl -0777 -ne 'print if /@if\(auth\(\)->check\(\) && auth\(\)->user\(\)\?->role === .admin.\)[\s\S]*settings\.users\.index/s' "$SIDEBAR" >/dev/null; then
      perl -0777 -i -pe "
        s{
          (\\s*<a\\s+href=\"{{\\s*route\\('settings\\.users\\.index'\\)\\s*}}\"[\\s\\S]*?>[\\s\\S]*?Users\\s+Management[\\s\\S]*?</a>)
        }{
          @if(auth()->check() && auth()->user()?->role === 'admin')\n$1\n@endif
        }gs
      " "$SIDEBAR"
      echo "   -> Wrapped Users Management link with admin guard in $SIDEBAR"
    else
      echo "   -> Admin guard already present in $SIDEBAR"
    fi
  else
    echo "   -> No explicit Users link found in $SIDEBAR (nothing to change)"
  fi
else
  echo "   -> Sidebar file not found ($SIDEBAR); skipping"
fi

echo "==> 4) If an older top nav exists, guard there too (best effort)"
if [ -f "$ALTNAV" ]; then
  if grep -q "route('settings.users.index')" "$ALTNAV"; then
    if ! perl -0777 -ne 'print if /@if\(auth\(\)->check\(\) && auth\(\)->user\(\)\?->role === .admin.\)[\s\S]*settings\.users\.index/s' "$ALTNAV" >/dev/null; then
      perl -0777 -i -pe "
        s{
          (\\s*<a\\s+href=\"{{\\s*route\\('settings\\.users\\.index'\\)\\s*}}\"[\\s\\S]*?>[\\s\\S]*?Users\\s+Management[\\s\\S]*?</a>)
        }{
          @if(auth()->check() && auth()->user()?->role === 'admin')\n$1\n@endif
        }gs
      " "$ALTNAV"
      echo "   -> Wrapped Users Management link with admin guard in $ALTNAV"
    else
      echo "   -> Admin guard already present in $ALTNAV"
    fi
  fi
fi

echo "==> 5) Clear caches so Blade/UI updates apply"
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan view:cache || true
$DC exec -T app php artisan route:cache || true

echo "==> Done. Log in as a standard user:"
echo "   • The Users Management item should be hidden."
echo "   • If they manually hit /settings/users, they should see the 403 page."
