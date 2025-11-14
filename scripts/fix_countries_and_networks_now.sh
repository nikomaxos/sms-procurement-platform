#!/usr/bin/env bash
set -Eeuo pipefail

ts="$(date +%F_%H-%M-%S)"
backup(){ [ -f "$1" ] && cp -a "$1" "$1.bak.$ts" || true; }

# 0) docker compose alias
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

# 1) Fix CountriesController@index to stop referencing $mccs and eager-load mccs
CC="app/Http/Controllers/CountriesController.php"
backup "$CC"
php <<'PHP'
<?php
$f="app/Http/Controllers/CountriesController.php";
$s=@file_get_contents($f);
if($s===false){fwrite(STDERR,"Missing $f\n"); exit(1);}

# Ensure use Illuminate\Http\Request; is present
if(strpos($s,'use Illuminate\Http\Request;')===false){
  $s=preg_replace('~^(namespace\s+App\\\Http\\\Controllers;\\s*)~m','$1'."\nuse Illuminate\\Http\\Request;\n",$s,1);
}

# Replace index() with a simple, robust version
$index = <<<'CODE'
public function index(Request $r)
{
    $per = max(1, min(1000, (int) $r->integer('per', 20)));
    $countries = \App\Models\Country::with('mccs')
        ->orderBy('name','asc')
        ->paginate($per);
    return view('countries.index', compact('countries'));
}
CODE;

if (preg_match('~public\s+function\s+index\s*\([^\)]*\)\s*\{.*?\}~s',$s)) {
  $s=preg_replace('~public\s+function\s+index\s*\([^\)]*\)\s*\{.*?\}~s',$index,$s,1);
} else {
  # If index() missing, append it before class end
  $s=preg_replace('~\}\s*\z~',"\n\n$index\n}\n",$s,1);
}

# Ensure edit() passes $mccs to the view
$edit = <<<'CODE'
public function edit(\App\Models\Country $country)
{
    $country->load('mccs');
    $mccs = $country->mccs;
    return view('countries.edit', compact('country','mccs'));
}
CODE;

if (preg_match('~public\s+function\s+edit\s*\([^\)]*Country\s*\$country[^\)]*\)\s*\{.*?\}~s',$s)) {
  $s=preg_replace('~public\s+function\s+edit\s*\([^\)]*Country\s*\$country[^\)]*\)\s*\{.*?\}~s',$edit,$s,1);
} else {
  $s=preg_replace('~\}\s*\z~',"\n\n$edit\n}\n",$s,1);
}

if(file_put_contents($f,$s)===false){fwrite(STDERR,"Write fail $f\n"); exit(1);}
PHP

# 2) Make countries index view independent of a global $mccs variable
CV="resources/views/countries/index.blade.php"
backup "$CV"
cat > "$CV" <<'BLADE'
<x-app-layout>
  <x-slot name="header">
    <h2 class="font-semibold text-xl text-gray-800 leading-tight">Countries</h2>
  </x-slot>

  <div class="py-6 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
    <div class="overflow-x-auto rounded-lg border bg-white">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
            <th class="px-4 py-3">Country</th>
            <th class="px-4 py-3">ISO2</th>
            <th class="px-4 py-3">MCCs</th>
            <th class="px-4 py-3">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100 text-sm">
          @forelse($countries as $c)
            <tr>
              <td class="px-4 py-2">{{ $c->name }}</td>
              <td class="px-4 py-2">{{ strtoupper($c->iso2 ?? '') }}</td>
              <td class="px-4 py-2">
                {{ $c->mccs ? $c->mccs->pluck('mcc')->unique()->implode(', ') : '' }}
              </td>
              <td class="px-4 py-2 text-right">
                <a href="{{ route('countries.edit', $c) }}" class="text-indigo-600 hover:underline mr-3">Edit</a>
                <form action="{{ route('countries.destroy', $c) }}" method="POST" class="inline">
                  @csrf @method('DELETE')
                  <button type="submit" onclick="return confirm('Delete this country?')" class="text-red-600 hover:underline">Delete</button>
                </form>
              </td>
            </tr>
          @empty
            <tr><td colspan="4" class="px-4 py-6 text-center text-gray-500">No results.</td></tr>
          @endforelse
        </tbody>
      </table>
    </div>

    <div class="flex items-center justify-between">
      <div class="text-sm text-gray-600">
        @if($countries->total())
          Showing {{ $countries->firstItem() }}–{{ $countries->lastItem() }} of {{ $countries->total() }} results
        @else
          Showing 0 of 0 results
        @endif
      </div>
      <div class="text-sm">
        {{ $countries->onEachSide(1)->links() }}
      </div>
    </div>
  </div>
</x-app-layout>
BLADE

# 3) Ensure NetworkMnc model computes mcc fallback + mcc_mnc
NM="app/Models/NetworkMnc.php"
backup "$NM"
mkdir -p app/Models
cat > "$NM" <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NetworkMnc extends Model
{
    protected $fillable = [
        'network_id','mcc','mnc','mcc_mnc',
        'created_by_user_id','updated_by_user_id',
        'created_by_source','updated_by_source',
        'is_deleted'
    ];

    public function network(){ return $this->belongsTo(Network::class); }

    protected static function booted()
    {
        static::saving(function(self $nm){
            // Fallback MCC if not provided: network->mcc or first country MCC
            if (empty($nm->mcc) && $nm->network) {
                $nm->mcc = $nm->network->mcc
                    ?: optional(optional($nm->network->country)->mccs->first())->mcc;
            }
            // Compute mcc_mnc
            $nm->mcc_mnc = trim((string)($nm->mcc ?? '') . (string)($nm->mnc ?? ''));
        });
    }
}
PHP

# 4) NetworksController: load mncs on edit; avoid non-existent cols on update
NC="app/Http/Controllers/NetworksController.php"
backup "$NC"
php <<'PHP'
<?php
$f="app/Http/Controllers/NetworksController.php";
$s=@file_get_contents($f);
if($s===false){fwrite(STDERR,"Missing $f\n"); exit(0);}

# Ensure edit() eager-loads mncs + country.mccs
if (preg_match('~public\s+function\s+edit\s*\([^\)]*Network\s*\$network[^\)]*\)\s*\{.*?\}~s',$s,$m)) {
  $edit = <<<'CODE'
public function edit(\App\Models\Network $network)
{
    $network->load(['mncs','country.mccs']);
    return view('networks.edit', compact('network'));
}
CODE;
  $s = preg_replace('~public\s+function\s+edit\s*\([^\)]*Network\s*\$network[^\)]*\)\s*\{.*?\}~s',$edit,$s,1);
}

# Replace any wrong audit columns in update() body
$s = str_replace(["'created_by_user'",'"created_by_user"'], ["'created_by_user_id'",'"created_by_user_id"'], $s);
$s = str_replace(["'updated_by_user'",'"updated_by_user"'], ["'updated_by_user_id'",'"updated_by_user_id"'], $s);

# Guard: if code writes ->created_by_user=, fix to *_id
$s = str_replace(['->created_by_user =', '->updated_by_user ='], ['->created_by_user_id =','->updated_by_user_id ='], $s);

file_put_contents($f,$s);
PHP

# 5) Clear caches
$DC exec -T app sh -lc 'php artisan optimize:clear && php artisan view:cache && php artisan route:cache'

echo "All set: Countries index fixed, countries view independent of \$mccs, NetworkMnc computes MCC+MCC-MNC, Networks edit eager-loads MNCs, and audit fields corrected."
