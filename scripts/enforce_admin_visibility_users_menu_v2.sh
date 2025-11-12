#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

SIDEBAR="resources/views/partials/sidebar.blade.php"
ERR403="resources/views/errors/403.blade.php"

echo "==> 1) Ensure friendly 403 page"
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

echo "==> 2) Hide 'Users Management' link in sidebar for non-admins"
if [ -f "$SIDEBAR" ]; then
  cp -a "$SIDEBAR" "$SIDEBAR.bak.$(date +%F_%H-%M-%S)"

  # Replace a naked Users Management link to a guarded one.
  # We match the first anchor that points to the users route and wrap it with an @if guard.
  perl -0777 -i -pe '
    my $guard = q{@if(auth()->check() && auth()->user()?->role === '\''admin'\'')};
    my $end   = q{@endif};

    # If already guarded, do nothing.
    if (/@if\(auth\(\)->check\(\) && auth\(\)->user\(\)\?->role === .admin.\)[\s\S]*route\(.\Qsettings.users.index\E./s) {
      # already guarded
    } else {
      s{
        (\s*<a\s+href="{{\s*route\(\s*'\Qsettings.users.index\E'\s*\)\s*}}".*?>.*?Users\s+Management.*?</a>)
      }{$guard\n$1\n$end}igsx;
    }
    $_;
  ' "$SIDEBAR" || true
else
  echo "   -> Sidebar file not found ($SIDEBAR); skipping"
fi

echo "==> 3) Ensure writable dirs in container (for Blade cache/errors)"
$DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rw storage bootstrap/cache'

echo "==> 4) Clear & rebuild caches"
$DC exec -T app php artisan optimize:clear || true
$DC exec -T app php artisan view:cache || true
$DC exec -T app php artisan route:cache || true

echo "==> Done. Test:"
echo "   • Login as STANDARD user -> Users Management menu should be hidden."
echo "   • Hit /settings/users directly -> Friendly 403 page should render."
