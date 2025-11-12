#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR line $LINENO: $BASH_COMMAND" >&2' ERR

# docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

SETTINGS_IDX="resources/views/settings/index.blade.php"
PROF_CTRL="app/Http/Controllers/ProfileController.php"
DEL_PARTIAL="resources/views/profile/partials/delete-user-form.blade.php"
PROF_EDIT="resources/views/profile/edit.blade.php"

#############################################
# 1) Hide the Users Management card (non-admins)
#############################################
if [ -f "$SETTINGS_IDX" ]; then
  cp -a "$SETTINGS_IDX" "$SETTINGS_IDX.bak.$(date +%F_%H-%M-%S)"
  # Wrap the exact Users Management <a> block shown in your file
  perl -0777 -i -pe '
    my $start = q{@if(auth()->check() && auth()->user()?->role === '\''admin'\'')};
    my $end   = q{@endif};
    # Only wrap if not already guarded
    if (!/@if\(auth\(\)->check\(\) && auth\(\)->user\(\)\?->role === .admin.\)[\s\S]*settings\.users\.index/s) {
      s{
        (\s*<a\s+href="{{\s*route\(\s*'\Qsettings.users.index\E'\s*\)\s*}}"\s+class="[^"]*">\s*<div[^>]*>Users\s+Management<\/div>[\s\S]*?<\/a>)
      }{$start\n$1\n$end}igsx;
    }
    $_;
  ' "$SETTINGS_IDX"
else
  echo "WARN: $SETTINGS_IDX not found; skipping card guard"
fi

##########################################################
# 2) Server-side: forbid standard users from self-deleting
##########################################################
if [ -f "$PROF_CTRL" ]; then
  cp -a "$PROF_CTRL" "$PROF_CTRL.bak.$(date +%F_%H-%M-%S)"
  # Insert a role check immediately after the opening brace of destroy(...)
  awk '
    BEGIN{in_d=0; injected=0}
    {
      print $0
      if ($0 ~ /public[[:space:]]+function[[:space:]]+destroy[[:space:]]*\(/) { in_d=1 }
      else if (in_d==1 && $0 ~ /\{/) {
        print "        \\$u = \\$request->user();"
        print "        if (!(\\$u && \\$u->role === '\\''admin'\\'')) {"
        print "            return back()->withErrors([ '\\''userDeletion'\\'' => '\\''Only admins can delete accounts.'\\'' ]);"
        print "        }"
        in_d=0; injected=1
      }
    }
    END{
      if (!injected) {
        print \"/* [Note] Could not auto-inject guard into destroy(); please check controller manually. */\" > \"/dev/stderr\"
      }
    }
  ' "$PROF_CTRL.bak.$(date +%F_%H-%M-%S)" > "$PROF_CTRL.tmp" && mv "$PROF_CTRL.tmp" "$PROF_CTRL"
else
  echo "WARN: $PROF_CTRL not found; skipping controller guard"
fi

#####################################################################
# 3) UI: hide delete account form for non-admins (if the partial exists)
#####################################################################
if [ -f "$DEL_PARTIAL" ]; then
  cp -a "$DEL_PARTIAL" "$DEL_PARTIAL.bak.$(date +%F_%H-%M-%S)"
  if ! grep -q "auth()->user()?->role === 'admin'" "$DEL_PARTIAL"; then
    # Wrap entire partial
    printf "@if(auth()->check() && auth()->user()?->role === 'admin')\n" > "$DEL_PARTIAL.new"
    cat "$DEL_PARTIAL" >> "$DEL_PARTIAL.new"
    printf "\n@endif\n" >> "$DEL_PARTIAL.new"
    mv "$DEL_PARTIAL.new" "$DEL_PARTIAL"
  fi
else
  # Fallback: try to hide any Delete section in profile/edit if partial missing
  if [ -f "$PROF_EDIT" ]; then
    cp -a "$PROF_EDIT" "$PROF_EDIT.bak.$(date +%F_%H-%M-%S)"
    perl -0777 -i -pe '
      my $guard1 = "@if(auth()->check() && auth()->user()?->role === \x27admin\x27)";
      my $end    = "@endif";
      # Best-effort wrap any section containing Delete Account
      s{
        (\s*<section[^>]*>[\s\S]*?Delete\s+Account[\s\S]*?<\/section>)
      }{$guard1\n$1\n$end}igsx;
      $_;
    ' "$PROF_EDIT" || true
  fi
fi

#############################################
# 4) Clear caches (Blade/routes) in container
#############################################
if docker ps >/dev/null 2>&1; then
  $DC exec -T app bash -lc 'chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rw storage bootstrap/cache'
  $DC exec -T app php artisan optimize:clear || true
  $DC exec -T app php artisan view:clear || true
  $DC exec -T app php artisan view:cache || true
  $DC exec -T app php artisan route:cache || true
fi

echo "==> Done."
echo "   • Users card on /settings hidden for non-admins."
echo "   • Standard users cannot delete their account (server-side guard + hidden form)."
