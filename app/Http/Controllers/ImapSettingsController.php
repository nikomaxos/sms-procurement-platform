<?php
namespace App\Http\Controllers;

class ImapSettingsController extends Controller {
    public function __construct(){ $this->middleware('auth'); }
    public function edit(){ return view('settings.imap.edit'); }
}
