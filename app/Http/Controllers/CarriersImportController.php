<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

class CarriersImportController extends Controller {
  public function __construct(){ $this->middleware('auth'); }
  public function run(Request $r){
    $code = Artisan::call('carriers:import', ['--fresh' => $r->boolean('fresh',false)]);
    return back()->with('status', "Import finished (code $code).\n".Artisan::output());
  }
}
