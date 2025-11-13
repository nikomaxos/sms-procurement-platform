<?php
namespace App\Http\Middleware;
use Closure;
use Illuminate\Http\Request;

class AdminOnly {
  public function handle(Request $request, Closure $next){
    $u = $request->user();
    $isAdmin = $u && ( ($u->is_admin ?? false) || (($u->role ?? ($u->type ?? '')) === 'admin') );
    abort_unless($isAdmin, 403);
    return $next($request);
  }
}
