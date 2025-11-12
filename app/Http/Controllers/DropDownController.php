<?php
namespace App\Http\Controllers;

class DropDownController extends Controller {
    public function __construct(){ $this->middleware('auth'); }
    public function index(){ return view('settings.dropdowns.index'); }
}
